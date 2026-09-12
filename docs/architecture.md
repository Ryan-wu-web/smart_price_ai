# 当前架构：本地有据购物工作流

更新：2026-09-12。本文描述实际实现；历史演进见[模块记录](modules/README.md)，验证范围见[评测](evaluation.md)与[验收](acceptance.md)。原需求中的远端记忆和目标指标不是当前事实。

## 调用链与事实来源

```text
Flutter 单／多目标拍照 → 识别API → 共享HTTP池 → VLM/LLM → Schema／有限修复
                        ↓ 精确缓存                    ↓ 识别上下文（未核验）
Flutter 聊天／确认条件 → chat JSON／SSE → 单会话锁 → SessionStore
  → 意图／规则需求解析 → 完整性判断 → 缺失或歧义则追问
  → 商品知识混合检索 → 补齐同品类完整目录 → 硬约束过滤
  → 软偏好规则评分 → 证据解释 → Schema校验 → 保存会话 → result/end
  → 同会话追问、对比、决策报告
  ← 明确选择的长期偏好 ← PreferenceStore（SQLite，用户确认／版本检查）

固定JSON目录 → Pydantic → ProductCatalog（18件、3品类、SHA快照）
  ├─ 字段切片／Metadata → BM25＋字符TF-IDF → RRF／规则重排
  ├─ 推荐工具的完整商品事实／逐条件证据
  ├─ 旧compare的固定样例展示
  └─ 旧report的按商品ID知识摘要
旧trend → 明确未接历史数据；旧suggest → 固定导航；旧filter仍为模型兼容路径
```

应用入口 `backend/app/main.py` 在lifespan内创建和关闭单进程httpx连接池，并加载目录和检索索引。所有模型客户端借用共享池；独立构造的客户端自行关闭。目录加载失败明确影响依赖它的接口，识别／旧模型聊天不因此被伪装成不可启动。

购物路径是**轻量确定性状态机**，不依赖模型生成名次或商品事实。旧LLM聊天仍可通过未建立购物状态、未提供shopping的新会话使用；Flutter购物聊天显式选择shopping。已有购物会话不会因为下一轮省略shopping而退回无据生成。

## 模块职责

下表路径相对仓库根目录。

| 路径 | 职责 |
| --- | --- |
| `backend/app/core/base_api_client.py`、`llm_client.py`、`vlm_client.py` | HTTP生命周期、超时、安全错误、模型输出及JSON修复 |
| `backend/app/services/recognition.py` | 图像校验与转换、单多目标精确缓存、结构化识别 |
| `backend/app/services/knowledge.py`、`models/knowledge.py` | 商品Schema、目录快照、来源与证据定位 |
| `backend/app/services/retrieval.py`、`core/retrieval_config.py` | 字段索引、关键词／稀疏向量召回、融合和检索重排 |
| `backend/app/services/requirements.py`、`core/requirements_config.py` | 规则需求解析、增量条件、待澄清项和显式编辑 |
| `backend/app/services/recommendations.py`、`core/recommendation_config.py` | 完整事实硬过滤、软偏好评分、逐条件证据 |
| `backend/app/services/workflow.py`、`models/workflow.py` | 工具封装、统一状态、节点追踪、异常和报告 |
| `backend/app/services/sessions.py`、`chat.py` | 会话持久化、摘要、锁、购物与旧聊天分流 |
| `backend/app/services/preferences.py` | 明确长期偏好、本地SQLite版本化读写 |
| `android-app/lib/screens/chat_screen.dart` | 购物对话、流式节点、条件确认与偏好交互 |
| `android-app/lib/models/shopping_decision.dart` | 客户端结构、证据归属和报告一致性校验 |

## 识别与模型边界

缓存身份为原始图片字节SHA-256＋任务模式＋模型／端点＋预处理及版本。单目标、多目标隔离，TTL 7天；过期或损坏不复用，原子写失败不影响本次已验证结果。不承诺相似重拍命中，尚无容量淘汰或同图并发请求合并。

图像经EXIF方向修正、RGB转换、最长边600px、JPEG质量75处理。Schema拒绝伪造坐标、非法数值和不可识别的输出。模型格式／Schema问题做有上限修复；网络、鉴权、超时不盲重试。单目标结构失败可有限两阶段降级，多目标失败明确错误，不伪装成空识别。真实模型尚未验收。

识别后人工编辑的上下文无价格也可传入聊天。它是待确认观察，不是目录证据或已核验SKU。识别品类需明确确认；不会把猜测出的价格、型号或品牌自动保存为长期偏好。

## 知识、检索与推荐：三层不能混淆

1. **事实层**：`backend/app/catalog/sample-products.v1.json`声明商品ID、品类、品牌型号、带单位参数、价格区间、用途、优缺点、排斥场景、选购建议、source/evidence ID。未知参数明确为null，不能改成0／false。文件SHA绑定证据快照。
2. **相关性层**：字段切片带商品ID、字段角色、JSON Pointer；Metadata精确过滤先于召回。BM25关键词与字符2–4 gram TF-IDF余弦相似度分别召回，按商品融合RRF并做覆盖率／字段质量重排。此向量是词法稀疏向量，未加载语义Embedding／Cross-Encoder或外部向量库。
3. **购买约束层**：候选补齐至指定品类完整目录，避免只取Top-k漏掉满足硬条件的商品。预算要求整个样例价格区间落在边界内；不满足或事实未知的硬条件拒绝。检索得分不决定购买资格或软排序。

软偏好在field/key维度去重；同维度多偏好共享权重。权重集中在`recommendation_config.py`：预算2、品牌1、用途2、功能2、参数2；按归一化满足度得到0–100分，无软偏好则0分。同分按商品ID稳定排序，未知软条件计0分。分数是已表达偏好匹配度，不是商品质量、销量或购买保证。

输出绑定完整商品事实、硬检查、软检查、JSON Pointer证据、分项贡献、已满足和未满足条件。自然语言解释由确定性证据模板生成，不让模型补写商品参数。自由文本优缺点会展示，但不自动做无限制语义推断。

## 需求与工作流

`UserRequirements`记录意图、条件及来源原句、条件ID、revision、撤销历史、待澄清分句。条件统一表达field/operator/value/strength/key/unit。完整性判断独立输出缺失信息、冲突和追问。

当前语法是有边界的规则，不是通用NLU：整句分句匹配、明确数值与单位、支持3个品类；无法解析的内容保留并追问，不偷偷忽略。品类／预算及明确数值界限为硬约束；未声明强度的一般品牌／用途／功能／文本参数默认软。最终评测显示这个默认值未必符合用户意图，应在下一轮增加澄清，而不是宣称已解决。

`WorkflowState`连同会话快照记录需求、已识别商品、assessment、recommendation（含候选、检索证据、排序）、report、status、trace、errors和重试信息。节点覆盖preferences、intent、requirements、completeness、clarification、retrieval、filtering、ranking、explanation、report、validation。工具封装使检索、过滤、排序、偏好读取、报告边界可追踪；不使用多Agent框架。

- 缺失／歧义：needs_clarification，返回问题，不伪造条件。
- 硬条件冲突：conflict；没有合格候选：no_candidates。候选保持空，建议只是待确认编辑，不直接放宽。
- 知识／索引／工具不可用：unavailable，保留失败节点和友好错误，不退回无据推荐。
- 状态版本不匹配或坏会话：409并保留旧文件；客户端先GET恢复，不重放POST。
- 报告复用已校验选择、证据和目录SHA；旧report则仅为单商品知识摘要，不代表个性化最优。

## SSE与保存顺序

协议包含status、delta、result、error、end。旧模型流需上游完整帧、结束标志及最终Schema；本地购物流发送可追踪状态和确定性文本，不能把它的低延迟误报为模型TTFT。

只有结构校验和会话保存成功后才产生成功终态。Flutter按完整帧增量解析，保留result为临时结果直至success end；异常、断流、取消不把临时结果写成成功。退出取消请求，不自动重试非幂等POST。服务端默认一轮流预算120秒、锁等待上限30秒；HTTP超时与解析修复集中配置。

## 短期会话与长期偏好

- **短期**：SessionStore保存完整成功消息、摘要和商品上下文，以及当前购物状态。摘要不删除原文，摘要失败保留历史；采用会话锁、同目录临时文件、fsync和原子替换。文件／Prompt有保护上限，超限要求新会话而非静默截断。
- **4E修复**：写入保留显式null，并在写盘前做JSON往返Schema校验。旧坏文件不自动填造事实或删除，仍提示新建会话。
- **长期**：SQLite存明确确认的稳定条件，GET查看、POST版本化新增／修改／删除。最多32项，confirmed必须真值，应用需明确偏好ID和版本；不从模型／识别中自动保存。预算按品类作用，不跨品类套用。
- 删除偏好不会自动改动已经确认的会话条件；SQLite失败明确报错，不偷偷切换另一个档案事实来源。会话仍可在不读取偏好的路径工作。

Redis可承担带TTL会话和多进程协调，PostgreSQL可承担账号隔离、长期偏好事务及审计；需要另行设计权限、CAS／锁、迁移和恢复。当前只完成接入评估及optional-infra Compose配置，**未实现远端适配**。默认文件＋SQLite无需这些服务启动，也不是“远端故障后自动迁移”的降级方案。

## 部署和验收限制

当前仅适合可信本地单用户／单worker；会话ID不是凭据，未实现账户归属、分布式锁、跨worker一致性或数据加密。默认Compose API绑定127.0.0.1。本轮未改依赖／锁文件、未部署或启动Docker。

工程回归、Flutter静态与bundle检查、80条合成评测及10次本机SSE已运行。拍照真实模型、真机UI／网络、APK和远端存储仍未验收；[真实指标与失败记录](evaluation.md)不能外推到这些路径。
