# Phase 3B：完整事实过滤与有据偏好排序

本地验证日期：2026-09-12（Asia/Shanghai）。这是独立API模块交付，不是整个项目升级完成或80条产品评测报告。

## 结果和范围

新增`POST /api/v1/recommendations`，消费3A完整需求state，执行真实的混合检索、同品类完整候选补齐、硬过滤、软偏好排序及逐条件证据校验。
未修改旧聊天／识别／Flutter交互；旧业务仍待迁移。新接口无需模型、Redis或PostgreSQL，也没有新增依赖。

### 修改文件

| 文件（仓库内） | 改动 |
| --- | --- |
| `backend/app/models/knowledge.py` | bool置于数字类型前，修复HTTP false→0.0；保留null和小数 |
| `backend/app/services/requirements.py` | 抽出只读analyze；解析输出兼容，推荐不增加虚假轮次 |
| `backend/app/core/recommendation_config.py` | 版本、政策、软权重、精度和上限集中配置 |
| `backend/app/models/recommendations.py` | 请求、事实引用、条件检查、分项、候选、淘汰和诊断Schema |
| `backend/app/services/recommendations.py` | 完整事实三态检查、过滤、加权排序、证据和无候选说明 |
| `backend/app/routers/recommendations.py` | 新增独立接口、工具失败安全503 |
| `backend/app/main.py` | 仅新增路由注册 |
| `README.md`、`docs/api.md`、`docs/architecture.md`、`docs/modules/README.md`、`docs/modules/03a-structured-requirements.md`及本文 | 启动／调用示例、当前边界和交付记录 |

未修改目录样例数据、依赖／锁文件、环境变量、Docker、数据库、旧SSE或客户端。测试和临时材料全部放`D:\smart_price_ai-validation`，未加入主仓库。

## 实际规则与取舍

1. **先评估需求**：pending、缺槽位、冲突直接返回问题；compare/explain/report意图不假装执行推荐。评估不变更state、revision或撤销历史。
2. **检索不等于购买资格**：复用2B BM25＋字符TF-IDF检索；查询最多240字符，截取时告警，但全部条件仍执行。补齐硬品类精确匹配的完整目录，防止只过滤top5导致假空结果。
3. **事实三态**：matched才通过硬条件；not_matched与unknown都阻断。未知不是false或0，参数单位和布尔类型必须正确；文本精确匹配，用途只采纳完整列表中的明确支持／排斥，缺失或互相矛盾为未知。
4. **保守预算**：整个价格区间必须满足预算，而非最低价；预算上限500的商品如果区间499–569仍不通过。
5. **确定性软分**：field/key为维度，预算2、品牌1、用途2、每个功能2、每个参数2。相同偏好去重；维度内满足比例乘权重，除以有效软维度权重总和，再乘100。未知和不满足为0。score保留6位小数，按score降序／ID升序；没有软偏好均为0，不推断“便宜优先”。
6. **证据不是模型编造**：每项检查引用同一商品的evidence_id/source_id、原字段值、目录JSON Pointer；缺字段引用现有parameters对象。返回完整商品缺点、排斥条件和选购建议，不能把没有做语义理解的文本冒称“风险已全部排除”。
7. **无候选不放宽**：逐商品阻断详情最多10条，阻断统计基于全部同品类商品。单项撤销后的数量也是同品类内的反事实计数，不承诺新state满足基础槽位。变更必须通过3A显式确认；仅添加更高预算不会解除旧低预算。
8. **异常边界**：空检索或索引故障／过期快照明确降级为同品类完整事实扫描，条件不变；目录不可用或过滤／评分／最终校验失败安全503。没有模型调用，所以本模块不声称验证了模型超时兜底。

配置、完整字段和HTTP状态见[API说明](../api.md#有据过滤与偏好排序phase-3b)。关键日志为retrieval、filter_rank、validate的状态与计数，不打印原始需求、偏好值或异常原文；尚不是持久化Agent State。

## 升级前基线

基线提交：`a3df80e8532ee9823957d188b6d274bd569feea5`。
在修改前实测：推荐路径返回404；商品`sample-shoe-01`的防水参数HTTP JSON是float 0.0，而非bool false。
随后先运行2项检查，**2项均按预期失败**；实现后原2项通过，日志均保留。
这仅是工程能力／类型基线，不是意图准确率、Recall@5或端到端质量基线。

## 实际验证

环境：沿用Python3.12.13、FastAPI0.110.0、Pydantic2.6.0；未安装依赖。

| 检查 | 实际结果 |
| --- | --- |
| 3B模块工程检查 | **55/55通过**，包含独立原始JSON预算／布尔组合判定、参数运算边界、排序公式、重复偏好、证据定位、类型／单位、硬未知、候选补齐、无候选、多轮确认、工具降级、状态不变和HTTP Schema |
| 初始失败检查复跑 | **2/2通过** |
| 3A、2B、2A回归 | **53/53、32/32、31/31通过** |
| Phase 1、1B v1回归 | **32/32、29/29通过** |
| 1C回归 | **首次34/35；未修改旧代码或旧脚本，复跑35/35通过**，详见下面的时序风险 |
| 后端内存compile | **45个Python源码文件通过**，不生成主仓库编译产物 |
| Flutter analyze --no-pub | **No issues found**；本轮没有Flutter改动 |
| PYTHONHASHSEED=1／173 | 含分项与证据的完整推荐响应一致 |
| 真实localhost Uvicorn | **15项POST情形通过**，另验证健康、旧知识布尔、证据布尔和OpenAPI；在独立临时工作目录启动，无模型密钥／Redis／PostgreSQL，进程已停止 |

真实HTTP覆盖：需求解析、推荐、追加不放宽、无候选、缺少确认422、确认撤销、再次推荐、冲突解析／阻断、歧义解析／阻断、报告意图／拒绝伪报告、拒绝relax参数、top_k上界。
HTTP耗时仅用于工程诊断，**不是模型首字时间**。本模块非流式、无模型，尚未产生产品质量指标或80条最终测试集结果。

### 保留的1C时序问题

首次失败为`test_whole_turn_timeout`末尾`closed`断言：旧脚本将**整个回合**超时设为10ms，却假设模型生成器一定已启动。
未改动旧源码／脚本，复跑35/35通过。进一步用30ms上下文准备和10ms回合预算复现：模型流根本未进入，仍正常输出error/end且不落盘，此时closed为空是合理行为。
这一诊断说明旧断言对上下文耗时敏感，但没有对首次进程做时间探针，因此不把该解释冒称首次失败的完整时序记录。
首次失败日志和诊断结果均保留；没有为了让检查变绿去修改旧聊天或增加宽松断言。

### 复跑

材料不随主仓库克隆分发。异地复跑需另行复制`D:\smart_price_ai-validation`；仅克隆项目仍能按README启动并请求独立API。

```powershell
Set-Location D:\smart_price_ai
$env:PYTHONIOENCODING='utf-8'
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase3b_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase3b_red_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase3b_socket_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase3a_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase2b_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase2a_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1_checks.py --output D:\smart_price_ai-validation\phase3b-phase1-results.json
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1b_v1_checks.py --output D:\smart_price_ai-validation\phase3b-context-results.json
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1c_checks.py
Set-Location D:\smart_price_ai\android-app
& C:\flutter\bin\flutter.bat analyze --no-pub
```

主要材料：`phase3b-baseline.json`、`phase3b-red-result.txt`、`phase3b-result.txt`、`phase3b-regressions.json`、`phase3b-*-regression.log`、`phase3b-phase1c-rerun.log`、`phase3b-timeout-diagnostic.json`、`phase3b-socket-results.json`、`phase3b-static-results.json`、`phase3b-flutter-analyze.log`。


### 外部验证文件SHA-256

| 文件 | SHA-256 |
| --- | --- |
| `phase3b_red_checks.py` | `daf60e069aa10251a01307a1e70c9d45a22336dc78ca28f4c3a50a4049752a4a` |
| `phase3b_checks.py` | `f938eb7052f40832b86516306e906becf3a15cb5ebbc47c4f4913588a2a7f5df` |
| `phase3b_socket_checks.py` | `388182ed3ea28d5537e61aea68436bb824018bcfa3ebeddb9bce73499d4f3fd9` |
| `phase3b_timeout_diagnostic.py` | `aea1f40c88480f2f73c07ea9c2350b3170e088e7f5eb70e03b21af12832ce67c` |

## 已完成、限制和后续

- **已完成并验证**：本模块独立API、完整事实过滤、集中偏好算法、分项证据、无候选／确认边界、只读需求评估、知识HTTP类型、降级、原有模块回归及本地HTTP。
- **已完成但覆盖受限**：尚未做生产负载、大目录性能、Docker构建、跨客户端并发；本阶段无需这些即可在本地调用。真实模型、真机仍未验证。
- **尚未完成**：识别实体进入结构化需求、旧聊天／Flutter状态和推荐卡片接入、有据决策报告、单Agent状态机、长期偏好管理、Redis／PostgreSQL方案、80条独立产品评测和端到端验收。
- **明确风险**：精确用途匹配会遗漏同义表达；完整目录扫描适合当前18条样例；固定二值偏好匹配不等于真实用户效用；自由文本风险不做语义推理；旧业务中的随机Mock、静默放宽及无证据报告仍未迁移。

## 回退与唯一下一步

新增接口与旧接口隔离，无数据库迁移。需要回退时反向撤销本模块4个新增源码文件、main注册、需求analyze提取及相关文档；知识布尔类型修复可独立保留。已推送历史只用正常反向提交，不强推，不执行reset；此次未执行回退。

**唯一下一步：Phase 4A——建立可追踪的确定性单Agent购物工作流，将需求解析、检索、硬过滤和有据排序接入实际购物对话，保持已有识别／SSE兼容；先完成服务端闭环，再接Flutter展示。**
