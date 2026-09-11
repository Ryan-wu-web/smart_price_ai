# Phase 2B：字段混合检索与可追溯证据

日期：2026-09-11。开发基线：`a22ea47`（Phase 2A）；保留Flutter＋FastAPI，不接真实电商，不增加依赖。

## 目的与交付范围

将2A的固定知识查询升级为可实际调用的检索工具：字段切片 → 前置Metadata过滤 → BM25与字符向量召回 → 商品级融合 → 确定性重排 → 返回原始字段证据。
本模块不生成LLM答案，不接入旧比价／聊天／Flutter，也不声称完整RAG购物链路已完成。
商品文件仍为18条虚构样例；参数和价格不能作为真实厂商事实。

### 文件范围

- 新增 `backend/app/core/retrieval_config.py`：集中检索参数、字段／角色规则与算法版本。
- 新增 `backend/app/models/retrieval.py`：输入、分项得分、片段证据、索引身份及响应Schema。
- 新增 `backend/app/services/retrieval.py`：只读索引构建、双路召回、融合、重排与安全日志。
- 修改 `backend/app/services/knowledge.py`：提供完整目录的隔离副本迭代，不受查询分页上限影响。
- 修改 `backend/app/main.py`：启动构建索引，故障仅隔离搜索能力。
- 修改 `backend/app/routers/knowledge.py`：增加 `POST /api/v1/knowledge/search`，保留原GET接口。
- 更新 README、`backend/.env.example`、API／架构文档、模块索引及本交付记录。
- 未修改商品样例JSON、Flutter、已有会话格式、依赖／锁文件或Docker配置。

## 实际实现

### 切片、Metadata与索引身份

字段规则覆盖名称／品类／品牌／型号、参数、价格、场景、优缺点、排斥场景及建议。
标量按字段，参数按键，列表按条切片；不将不同列表项拼成窗口，不截断事实文本。
每个片段关联商品／证据／来源ID、字段路径、目录JSON Pointer；品类／品牌由商品Metadata映射参与过滤。
证据value来自目录校验后快照的字段值（沿用2A的字符串首尾空白规范化），text仅做确定性格式化。false/null、计量单位及负向描述保留，不推断为支持或满足。

当前构建 **370片段、690关键词词项、2182向量词项**，其中词项数指两个词表的不同特征数，不是向量模型参数数。
样例SHA：`994d9a90d7d19f58c2e09102654d770ff29f9c49e4853bf25f94a5cb9f76951c`。
索引指纹：`09ddba4bf2c9468cca0b7eee12e9c798fd376af19011080dcf8e071a4dcd6948`；算法版本 `field-hybrid-v1`。
指纹组合目录身份、配置、字段／角色规则和算法版本，不是签名。以后改变算法语义需递增算法版本；改样例需递增revision；修改后重启，不提供热加载。

### 召回与重排公式

`core/retrieval_config.py`集中配置以下默认规则，不在Prompt里隐藏排序权重：

1. **分析**：NFKC、小写；汉字连续段取二元词项，长度为1的连续段保留单字；ASCII字母／数字及连字符型号按词项处理。不是中文分词模型。
2. **关键词通道**：BM25。语料单位是片段，使用全库片段统计，精确Metadata过滤后才累计匹配分数。
   - `idf(t)=ln(1+(N-df(t)+0.5)/(df(t)+0.5))`。
   - `score(q,d)=Σ idf(t) × tf(t,d) × (k1+1) / [tf(t,d)+k1×(1-b+b×len(d)/avglen)]`。
   - 对去重查询词项求和；默认 `k1=1.2, b=0.75`。
3. **向量通道**：字符2–4元片段的稀疏TF-IDF；纯数字编码完整词项，不做数字子串匹配。
   - `idf(t)=ln((N+1)/(df(t)+1))+1`，`weight(t,d)=(1+ln(tf(t,d)))×idf(t)`。
   - 片段及查询向量均L2归一化，按共享词项点积计算余弦，最低相似度0.08；查询中词表外特征不参加向量计算。
   - 无模型下载／向量数据库，**不是预训练语义Embedding**，阈值只是当前工程默认值，未在最终测试集调优。
4. **商品聚合**：每路先按商品取最大片段分，按分数降序／商品ID升序排列，各保留前40个；两个通道都在品类／品牌过滤后截断。
5. **融合**：仅对入选通道候选投票，`F=(k+1)×Σ w_channel/(k+rank_channel)`，`k=60`，hybrid两路各0.5；单路mode该通道权重1。相同商品的多片段不增加投票次数。
6. **证据选择**：匹配片段按`max(BM25/(1+BM25), cosine)`降序，然后字段角色分降序、字段路径升序，默认保留5条。
7. **检索重排**：`score=0.6×F+0.3×C+0.1×Q`。
   - `C`为**返回证据**覆盖的查询关键词去重数／查询关键词去重总数；不是所有用户需求覆盖率。
   - `Q`为返回证据中最高角色分：identity/fact=1、benefit=0.9、advice=0.6、caveat=0.5。
   - 输出按score降序／商品ID升序，top_k默认5、上限10，商品不重复；记录两路分数／名次、F/C/Q、字段及匹配原因。

这是轻量、可复算的资料相关性Rerank，不是Cross-Encoder或学习排序，更不是购物硬约束／软偏好算法。
role只是字段分类，fact可能是false、null或否定描述。检索分数不能用作“满足条件”或购买置信度。

### API、故障与生命周期

API完整输入／返回字段见 [API文档](../api.md#样例知识混合检索phase-2b)，启动与PowerShell调用见 [README](../../README.md#查询样例知识证据phase-2b)。
服务初始化每worker加载一次只读快照及索引；返回值隔离拷贝，无查询缓存、写接口、外部网络或用户偏好持久化。
query最多240字符、top_k最多10；索引最多20,000片段、每路200,000词项，超限拒绝建立索引，不静默只索引一部分。

- 精确Metadata无匹配 → 200、空hits、`no_metadata_match`。
- 无词项／向量匹配 → 200、空hits、`no_term_match`；不随机补商品，不放宽过滤。
- 输入错误 → 422；搜索索引／内部工具失败 → 503与安全中文提示。
- 目录失败 → 浏览与搜索503，但不阻止进程；仅索引失败 → 搜索503、目录浏览继续。
- 日志只包含模式、计数、索引指纹、错误类型，不记录查询内容、商品正文和原始异常。
- `/health`是存活接口，不是索引就绪保证；Docker COPY规则已覆盖新Python文件，未实际构建镜像。

## 验证过程与真实结果

主仓库不放测试或临时脚本，均放在 `D:\smart_price_ai-validation`，仅本机保存，不随克隆分发。
这些是开发期工程检查，不是80条产品评测，不汇报意图准确率、Recall@5、推荐有据率或端到端成功率。

| 验证 | 实际结果 |
| --- | --- |
| 修改前接口基线 | health200、目录18条、新搜索接口404；保存于phase2b-baseline.json |
| 新模块首次检查 | 新检索模块不存在导致ModuleNotFoundError；phase2b-red.log |
| 首次实现后检查 | 23项中2项失败：数字子串误匹配；前缀型号同时匹配鞋与包导致用例预期有歧义 |
| 修复／澄清 | 数字改完整匹配；前缀验证明确运动鞋品类，不强行将鞋排在同前缀包之前 |
| 扩充后的模块检查 | **32/32通过**：Schema、双路独立性、数值公式、余弦归一化、105条目录完整性、前置过滤、去重、证据原值、并发与故障隔离 |
| Phase2A回归 | **31/31通过** |
| Phase1／1B v1适配／1C回归 | **32/32、29/29、35/35通过** |
| 独立进程确定性 | PYTHONHASHSEED=1／173的完整响应一致 |
| 后端内存compile | **37个Python源码文件通过** |
| Flutter analyze --no-pub | **No issues found**；无Flutter源码修改 |
| 本地真实Uvicorn HTTP | hybrid／keyword／vector查询、原证据字段对应、空结果、422、旧GET及OpenAPI通过；无需模型或数据库，从临时工作目录启动通过，进程已停止 |

本地HTTP检查的`雨天通勤＋运动鞋`首条是`sample-shoe-04`；`Rain-02`关键词模式能定位该样例，`rain-0＋运动鞋`向量模式可召回，而关键词模式没有完整词项匹配。
这只是有针对性的开发期用例，不代表自然语言整体检索质量已达标。HTTP耗时保存在socket结果中，**不是大模型首字延迟**。

### 复现

```powershell
Set-Location D:\smart_price_ai
$env:PYTHONIOENCODING='utf-8'
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase2b_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase2b_socket_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase2a_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1_checks.py --output D:\smart_price_ai-validation\phase2b-phase1-results.json
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1b_v1_checks.py --output D:\smart_price_ai-validation\phase2b-context-results.json
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1c_checks.py
Set-Location D:\smart_price_ai\android-app
& C:\flutter\bin\flutter.bat analyze --no-pub
```

原Phase2A／1C检查仍写原来的结果文件；本轮另存副本，不修改历史检查逻辑。
当前材料：`phase2b-results.json`、`phase2b-socket-results.json`、`phase2b-knowledge-regression.json`、`phase2b-phase1-results.json`、`phase2b-context-results.json`、`phase2b-stream-results.json`及相应日志；汇总为`phase2b-delivery-checks.json`。
运行环境沿用Python3.12.13、Pydantic2.6.0、FastAPI0.110.0。异地复现需要另行交付外部验证目录；只克隆主仓库可启动／调用API，但不能凭空获得这些脚本。

| 外部检查脚本 | SHA-256 |
| --- | --- |
| `phase2b_checks.py` | `2b91cc81fc3723b30f45b61d3415ae64c6611480368dab74dd6517da66469c20` |
| `phase2b_socket_checks.py` | `9487eedd2447c87f370d01e99a819bd76954fcec4dd370d338baa0a871abfff5` |
| `phase2a_checks.py` | `4070b395efdbd53ede25b025c51e076d72dd20a66c13a1445265bcaa42047c13` |
| `phase1_checks.py` | `c4f20e5061d3c76cb0c48980f6a161ec8eba93932965b5506ac6a750d3f1ef41` |
| `phase1b_v1_checks.py` | `e53a9a514f0f5040cf2400b4f35e915e5757c797adf2c62d1f64de107d1cd3c4` |
| `phase1c_checks.py` | `0f2ca76779dcfc47ae36fc492027de9f03164ff881cdd812806465c76ad87188` |

## 剩余风险与边界

- **已完成并验证**：字段索引、精确Metadata前置过滤、关键词／字符向量、融合／确定性重排、结构输出、样例字段定位、工程回归及真实本地HTTP。
- **环境／覆盖限制**：未测真实模型、Flutter真机、Docker构建、生产并发及大语料性能；本模块不调用模型。
- **尚未完成**：预训练语义Embedding（本地字符向量不冒充它）、自然语言需求结构化、预算／功能硬约束、软偏好排序、工作流、长期偏好、业务生成链路接入及80条独立评测。
- **已知检索局限**：同义词、单汉字、否定语义和未知商品没有专门理解；查询词表外特征被丢弃可能放大少量字符重合。没有词项命中不证明商品不存在。
- **证据选择局限**：默认只返回5条相关片段，并非完整商品风险清单；调用方需要完整事实时应读取商品详情，不能只靠片段判断所有硬约束。
- **旧链路风险**：旧随机Mock、静默放宽及无证据报告仍未改写；不得因新增搜索API而宣称旧推荐已有证据。

## 回退与唯一下一步

无数据库迁移或会话格式更改。反向撤销本模块新增检索文件、路由、启动初始化及文档即可保留2A知识查询；完整目录迭代接口也随该模块撤回。已推送历史仅用反向提交，不reset或强推；未实际执行回退。

**唯一下一步：Phase 3A——结构化用户需求Schema与增量需求解析，明确已确认条件、待补充信息以及硬约束／软偏好边界，为后续过滤排序与工作流接入提供输入。**
