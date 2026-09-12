# 离线评测与可复现结果（Phase 5）

实测日期：2026-09-12（Asia/Shanghai）。这是本地合成数据上的确定性购物工作流评测，**不包含真实拍照准确率、真实LLM质量、手机网络或真机交互**。需求文档中的百分比仅为目标，不是这里的结果。

> **版本边界补充（v2收尾）：** 本文数字、失败案例及原复现包冻结于`e4ea227`／requirements-rules-v1。之后已根据曝光的失败补充口语、中文数字与强度澄清；该工作只做[工程回归](modules/06a-language-clarification.md)，没有新的未曝光最终集，因此不替换本文结果，也不宣称新版本达到这些或更高的独立质量指标。

## 版本与测量顺序

| 对象 | 固定标识 |
| --- | --- |
| 升级前源码快照 | `d02b1d0`，清理后、Phase 1之前 |
| 数据冻结时的候选源码 | `890f0d6538989231e3cbe13e65c0c1f03aefd126` |
| 开发修复后实际评测源码 | `e4ea227c180a204af263a45edf1569b8d9651410` |
| 数据SHA-256 | `a4746a1ae7670fc31b7472a1e7d2c4f951492f756172ac76edf513752ee3fe06` |
| 商品目录SHA-256 | `994d9a90d7d19f58c2e09102654d770ff29f9c49e4853bf25f94a5cb9f76951c` |

1. 作者脚本建立并冻结80条数据、分组和金标，保留manifest。
2. 在隔离旧源码快照运行基线探针，再运行当前开发集。这是升级后**重放旧源码**的基线，不冒充升级前已经完成的前瞻测量。
3. 开发集暴露未知参数null序列化丢失，引发下一轮SESSION_CORRUPT；生产4E修复保留null并写前往返校验。同时修复评估器将500与500.0视为不同数值的问题，布尔值不与数值混同。
4. 原始开发失败结果保留为`development-prefixed-evaluator-*`，不覆盖；不修改冻结金标。开发修复后40条通过。
5. 最终集首次运行（02:26:42 +08:00）得到33/40。截至Phase 5冻结交付时未用最终集修改生产算法或金标。交付时在隔离源码复现包重跑，仅核对指标与失败列表完全一致，不进行调参。

manifest中的候选SHA是冻结时版本；结果JSON中的candidate_code_sha是实际测量版本。这两个值不同有上述开发修复依据，不应悄悄覆盖历史。

## 数据结构、划分与局限

80条JSONL，8组各10条；每组前5条development、后5条final_test，共40开发＋40最终。组为intent、slots、recall、hard、soft、evidence、structure、fallback。最终集每组只有5条，样本少导致结果波动大。

通用字段为id/group/split/kind。parse样本带message、gold_intent或gold_conditions；search样本带query/category/relevant_ids；chat样本带消息轮次、预期状态及按场景配置的条件、首位商品、报告或注入故障。金标条件使用field/operator/value/strength/key/unit。

```json
{"id":"intent-01","group":"intent","split":"development","kind":"parse","message":"推荐耳机","gold_intent":"recommend"}
```

数据由实现代理编写，为合成测试场景，不是独立人工标注或真实用户流量；主要覆盖3品类、18条目录样例。即使划分与冻结规范，也存在作者偏差与相似表达泄漏风险。最终集失误不能被开发集100%掩盖；本集不能支持生产泛化结论。

## 升级前基线：N/A，不是0分

`baseline.json`记录实际执行的30次新契约HTTP探针（20次requirements/parse、10次knowledge/search，均404）和50个聊天场景的OpenAPI能力判断（旧ChatRequest没有shopping工作流）。后50项没有调用旧模型聊天，不是80次模型请求。

旧compare单次观察返回：运动鞋42条、耳机18条、双肩包468条，带evidence_id的均为0；旧trend返回90个模拟点。这是旧行为观察，不是商品质量分数，也不代表真实行情。

旧版本不存在可比较的结构化需求／检索／有据工作流，且未配置真实上游，因此本次各质量指标和可比较模型首字基线均为**N/A**。不能声称“准确率从0提升到100%”。此前12项工程基线仅1项通过也不是产品质量基线。

## 指标定义与真实结果

所有百分比均为分子／分母；没有分母时为N/A，不靠空输出获得100%。

| 指标 | 分子／分母与计数范围 | 开发集 | 最终集 |
| --- | --- | --- | --- |
| 意图识别准确率 | intent组意图完全一致的样本／intent组样本 | 5/5＝100% | **2/5＝40%** |
| 需求槽位整句精确匹配 | slots组活动条件集合完全一致的句子／slots组句子 | 5/5＝100% | **3/5＝60%** |
| 槽位micro Jaccard | slots组逐句条件集合交集数之和／并集数之和 | 14/14＝100% | **10/15＝66.67%** |
| Recall@5 micro | 5个search场景前5商品命中金标ID数之和／金标相关ID数之和 | 5/5＝100% | **7/7＝100%** |
| 金标硬约束满足率 | hard组返回商品中满足全部金标硬条件的件数／该组返回商品件数 | 13/13＝100% | **9/12＝75%** |
| hard场景非空覆盖 | hard组有候选场景／hard组场景 | 5/5＝100% | 5/5＝100% |
| 推荐有据率 | 返回推荐通过完整事实、证据及分数检查的件数／全部返回推荐件数 | 74/74＝100% | **64/64＝100%** |
| 结构化输出成功率 | 最后一次响应符合成功Schema或预期错误契约的场景／全部场景 | 40/40＝100% | **40/40＝100%** |
| 购物工作流场景成功率 | chat场景全部目标检查通过数／chat场景数 | 25/25＝100% | **23/25＝92%** |
| 软偏好首位符合率 | 带top_ids场景中首位商品符合金标数／该类场景数 | 5/5＝100% | 5/5＝100% |
| 异常回退成功率 | fallback组全部检查通过数／fallback组场景数 | 5/5＝100% | **4/5＝80%** |
| 全部子任务通过率 | 所有检查均通过的场景／全部场景 | 40/40＝100% | **33/40＝82.5%** |

### 容易误读的分母

- 槽位条件比较field/operator/value/strength/key/unit，不比较自动分配ID；500与500.0同值，true与1不同。micro Jaccard会惩罚多报，**不是token accuracy或通用slot F1**。
- Recall按相关商品计数，不是按query；5个最终查询对应7个相关ID，不能写成“7次查询全部命中”。
- 有据检查逐条比对商品完整事实与冻结目录，核对product/evidence/source归属、JSON Pointer值、所有**已解析**硬条件和分项合计。它验证忠实于目录及解析状态，**不保证解析状态忠实于用户原意**；因此有据100%与金标硬约束75%可以同时发生。
- 结构化成功包含符合预期的422/409/502/504安全错误。合法错误只说明协议正确，不表示购物任务成功。
- 购物场景分母每份25条，另外15条是parse/search子任务，不包含在内。报告多轮算一个场景；不包含“拍照→模型→手机”全链路。
- 故障样本通过工具桩／异常注入模拟catalog、retrieval、工具和ModelTimeoutError／ModelOutputError，不是网络上真实服务发生超时。真实模型调用为0。
- 本评测器运行完成返回exit0，即使存在质量失败；判断质量要读取failures和metrics。复现检查通过只说明同样结果可以重复得到。

## 首字响应：单独走真实本机HTTP流

`phase5_latency.py`启动临时127.0.0.1 Uvicorn单worker，使用httpx逐行消费10次SSE，轮换3品类。起点是发起POST前，终点是第一个非空delta.reply；status事件不算首字。所有请求验证success end且拼接delta等于result。

| 项目 | 本次实测 |
| --- | --- |
| 样本数 | 10 |
| 首次新连接样本 | 22.1049ms |
| 中位数 | **15.1255ms** |
| P95（nearest rank，第10个有序样本） | **30.9966ms** |
| 最小／最大 | 13.2722ms／30.9966ms |

启动时间不计，第一次新连接、后续keepalive；不代表全部冷启动。它测的是**本机确定性工作流首文本**，不是LLM首token、识图、移动网络或前端首屏。ASGI TestClient记录的elapsed不拿来冒充网络首字。临时服务已终止，延迟重跑通常会变化。

2026-09-12 13:57的便携脚本重跑同样10次，首文本中位36.10ms、P95 92.42ms；结果保存在复现包rerun，未覆盖上表首次测量。运行负载与环境会影响延迟，不能把首次小样本数字当作稳定性能承诺。

## 失败案例与下一轮方向

| ID | 用户表达／预期 | 实际及归因 |
| --- | --- | --- |
| intent-07 | 帮我比较两款耳机 → compare | unknown；有限意图词表不能覆盖“两款”等修饰 |
| intent-08 | 能解释一下这双鞋为什么合适吗 → explain | unknown；口语和指代未覆盖 |
| intent-09 | 帮我出一份购物报告 → report | unknown；报告意图目前要求明确命令 |
| slots-06 | 耳机控制在五百块以内 → 耳机＋500硬上限 | 未提取；句式、中文数词未覆盖 |
| slots-07 | 给我找个背包，最多六百，能放16寸电脑 → 品类／预算／隔层 | 未提取；别名、中文数词、非标准参数句式未覆盖 |
| hard-08 | 推荐运动鞋，预算1000元，颜色黑色；金标将颜色视为hard | 当前颜色默认soft，5件中3件非黑；这是强度解析与金标不一致，不是已确认hard过滤漏掉 |
| fallback-09 | 推荐运动鞋，预算1000元，防水等级IPX8；金标预期无候选 | 默认soft，实际ready并显示未知；应澄清强度，而不是宣称IPX8已满足 |

下一轮先增加中文数词、口语／指代及受控别名覆盖；对重要参数强度不明确时先追问，再决定hard/soft。业务修改应使用开发集，并准备**新的独立测试集**，不修改本次最终金标刷分。暂不引入重型Agent或下载模型以掩盖规则边界。

## 工程回归（不等于80条产品评测）

| 套件 | 实际结果 |
| --- | --- |
| Phase 1当前契约适配 | 32/32 |
| 1B会话／上下文 | 29/29 |
| 1C SSE | 35/35 |
| 2A目录／2B检索 | 31/31、32/32 |
| 3A需求／3B排序 | 53/53、55/55 |
| 4A工作流／4C偏好／4D旧接口 | 34/34、27/27、15/15 |
| 4E多轮null往返／坏会话 | 2/2（包含18次聊天及磁盘恢复） |
| Dart SSE／购物结构 | 26/26、20/20 |
| Dart识别上下文 | 人工编辑保留、未知价格不伪造，检查通过 |

Python套件合计345项通过，套件之间有覆盖重叠，不宣称345个独立业务场景。原始Phase1检查31/32，失败项仍要求无目录ID报告200且建议／报告必须调用模型，与4D新契约冲突；保留原日志，以独立继承检查验证无ID422、有效ID200、仅filter/chat调用共享模型池，而非简单跳过。

最初两次命令漏传`--output`退出2，旧日志保留，已正确重跑；当前适配器初次误用了不存在的目录ID，核对后改为sample-audio-01，未改生产逻辑。AnyIO TestClient资源警告仍见日志。Flutter analyze无问题、build bundle exit0；后端语法与Compose配置等最终检查见[交付记录](modules/05-evaluation-delivery.md)。

## 如何复现（材料不进入主仓库）

原始材料：`D:\smart_price_ai-validation\phase5`。独立复现目录：`D:\smart_price_ai-validation\smart-price-ai-evaluation-2026-09-12`，同名ZIP在验证目录根。ZIP包含：

- 固定旧／新backend源码快照及revision，不依赖切换主仓库分支。
- 冻结JSONL／manifest、首次测量结果／原始响应／日志、原始评估脚本。
- 便携版baseline/eval/latency脚本和复现结果检查；只适配路径、输出目录和源码revision读取，评分逻辑未变。
- 环境、完整性SHA清单与包内README。重跑写入rerun，不覆盖original-results。

沿用本机虚拟环境，不安装新依赖；解压到其他位置后修改下面路径：

```powershell
$python = 'D:\smart_price_ai\backend\.venv\Scripts\python.exe'
$bundle = 'D:\smart_price_ai-validation\smart-price-ai-evaluation-2026-09-12'
$env:PYTHONIOENCODING = 'utf-8'
& $python "$bundle\verify_integrity.py"
& $python "$bundle\phase5_baseline.py"
& $python "$bundle\phase5_eval.py" --split development
& $python "$bundle\phase5_eval.py" --split final_test
& $python "$bundle\verify_reproduction.py"
& $python "$bundle\phase5_latency.py"
```

实际在隔离快照重跑后，development和final_test的metrics、failures、数据SHA、源码SHA、provider_calls与原结果完全一致。便携runner支持SMART_PRICE_SOURCE、SMART_PRICE_BASELINE、SMART_PRICE_EVAL_OUTPUT；默认使用包内快照。不要用更改过的源码revision文件伪装原版本，先验SHA。

测量环境：Windows 11、Python 3.12.13、FastAPI 0.110.0、Pydantic 2.6.0、httpx 0.26.0、Uvicorn 0.27.0、AnyIO 4.15.1；Flutter 3.24.5、Dart 3.5.4。依赖安装与跨环境再现需自行核对，首次质量结果以原始JSON为准。

**仅克隆GitHub源码不会自动获得测试脚本／数据包**，这是用户“主仓库不保留测试脚本”的交付边界。请备份本机ZIP；本轮没有将独立验证材料上传其他服务。
