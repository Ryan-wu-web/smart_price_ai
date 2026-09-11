# Phase 3A：结构化需求与可追溯增量编辑

日期：2026-09-11。基线提交：`e72b7007cf66d2790c461604225b9887d74f0615`。
本记录是工程交付，不是80条独立产品评测；没有把目标指标当成实测结果。

## 目的与实际范围

为Phase 3B过滤／排序提供严格、可追问且不会自动放宽的输入，保持旧Flutter＋FastAPI链路兼容。
现有 `/filter` 仍由模型返回通用字典，chat仅保存历史、摘要和识别商品，没有统一结构化需求；因此本阶段新增独立接口，不直接迁移旧调用方。
采用保守、全分句规则解析，复用Python标准库与已有Pydantic/FastAPI；没有新依赖、模型调用、框架、数据库、下载或数据迁移。
本阶段不删除有效业务代码，不在主仓库添加test文件或临时脚本。

### 修改文件

| 文件 | 用途 |
| --- | --- |
| `backend/app/core/requirements_config.py` | 品类／功能／参数词表、单位、前缀、基础必填槽位和容量配置 |
| `backend/app/models/requirements.py` | 需求、来源、待补充、显式编辑、冲突及最终响应Schema |
| `backend/app/services/requirements.py` | 完整分句解析、增量交集、显式撤销、冲突和问题生成、安全计数日志 |
| `backend/app/routers/requirements.py` | 独立 `/api/v1/requirements/parse`，422／409与结构化业务状态 |
| `backend/app/main.py` | 仅增加路由注册，不改旧服务或lifespan |
| `backend/.env.example` | 说明该模块不需模型配置、数据库或新变量 |
| `README.md`、`docs/api.md`、`docs/architecture.md`、`docs/modules/README.md`、本文件 | 使用示例、Schema、当前边界、验证及剩余工作 |

## 实现行为与关键取舍

1. **统一需求**：意图、预算、品类、品牌、用途、功能、核心参数和排斥条件；有效确认ID、待补充项、来源原句与轮次。
2. **明确硬／软**：预算和品类默认硬；品牌、用途、功能、文本参数默认软，明确“必须”才硬；ne排斥为硬条件。eq/min/max不交给LLM解释排序。
3. **增量而不覆盖**：重复有效条件去重，不同硬条件按交集保留。先500后800不会提高实际预算；必须明确确认撤销旧ID。保留removed_turn记录，避免更正过程不可追踪。
4. **不理解就追问**：未支持表达／模糊金额／双重否定／更正进入pending；下一轮仍保留，显式处理后才解除。原句不用于Prompt执行或长期偏好推断。
5. **冲突可见**：标量硬条件不同值、要求与排斥同值、空数值范围、唯一允许值又被排斥、已知品类不适用数值参数；返回冲突ID、原因和确认建议，不静默放宽。
6. **类型不混用**：人民币、克、小时、升、英寸分开；单耳、整机与鞋／包重量键不混用。新接口真实HTTP输出的布尔true/false可再次作为严格输入。
7. **状态边界**：客户端携带完整state，服务无状态；不改Phase 1B会话格式，不读模型摘要，不写长期记忆。source不是认证证据，confirm_changes不是身份授权。
8. **容量与回退**：最多1000轮，条件／待补充各128条，单句500字、消息4000字。超限或无效ID拒绝整个更新；在副本上修改，不截断或污染调用方输入。

`ready`只表示基础购物信息（意图、硬品类、硬预算上限）齐备，没有未处理分句或检测到的冲突。它不是“有商品可买”、候选排名成功或Agent执行许可。报告、解释等意图的专用完整度策略留给后续工作流。

完整请求／响应和确认编辑例子见 [API](../api.md#结构化需求与增量编辑phase-3a)，本地调用见 [README](../../README.md#解析并持续补充购物需求phase-3a)。

## 实际验证过程

| 阶段／检查 | 实际结果 |
| --- | --- |
| 修改前接口基线 | 在e72b700源码上请求新端点返回404，期望200的检查失败；只记录能力缺口，不换算成需求识别准确率 |
| 服务实现前Red | 外部检查无法导入尚未创建的 `app.services.requirements`，确认实现缺失 |
| 首轮实现检查 | 45项通过，随后主动添加边界用例，而非仅接受首轮绿色结果 |
| 审查暴露的问题 | 单位省略误解、中文千分位误拆、“品牌随便”被当具体品牌、pending超量触发Schema异常、数值单点又排斥未检出 |
| 修复 | 歧义保留pending；容量在追加前检查；补充数值单点排斥冲突；新增失败检查后修复 |
| 真实HTTP暴露的问题 | 新响应把功能true序列化为1.0，下一轮携带state返回422；仅Python对象检查未覆盖 |
| HTTP修复 | 布尔联合类型放在数值之前；新增true／false往返与小数保留检查，本地多轮HTTP通过 |
| 最终Phase 3A检查 | **53/53通过**：Schema、意图、硬软、单位、增量／去重／显式撤销、输入隔离、待补充、冲突、容量、JSON／HTTP往返及旧路由存在性 |
| Phase 2B／2A回归 | **32/32、31/31通过** |
| Phase 1／1B v1／1C回归 | **32/32、29/29、35/35通过** |
| 后端内存compile | **41个Python源码文件通过**，不在主仓库新增编译产物 |
| Flutter analyze --no-pub | **No issues found**；本轮无Flutter代码修改 |
| 独立进程确定性 | PYTHONHASHSEED=1／173完整响应一致；无随机需求排序或ID |
| 真实localhost Uvicorn | 新建、多轮、冲突、确认替换、歧义、422、409、容量上限9项请求通过；旧知识查询／检索、OpenAPI和独立工作目录启动通过；临时进程已停止 |

本地HTTP未配置模型、Redis或PostgreSQL，证明该独立模块不依赖它们；不证明真实模型或未来记忆实现可用。
HTTP耗时保留在socket结果中，**不是首字响应时间或产品质量指标**。工程检查属于开发期验证，不能用作未调参的最终测试集。

### 复现命令及材料

验证材料统一放 `D:\smart_price_ai-validation`，不随主仓库克隆分发。异地复跑需要另行复制该目录；仅克隆项目仍可按README启动并调用API。

```powershell
Set-Location D:\smart_price_ai
$env:PYTHONIOENCODING='utf-8'
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase3a_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase3a_socket_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase2b_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase2a_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1_checks.py --output D:\smart_price_ai-validation\phase3a-phase1-results.json
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1b_v1_checks.py --output D:\smart_price_ai-validation\phase3a-context-results.json
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1c_checks.py
Set-Location D:\smart_price_ai\android-app
& C:\flutter\bin\flutter.bat analyze --no-pub
```

基线脚本仅记录升级前404，不用于在升级后的源码上宣称旧版本效果。
主要材料：`phase3a-baseline-result.txt`、`phase3a-red-result.txt`、`phase3a-review-red-result.txt`、`phase3a-http-red-result.txt`、`phase3a-result.txt`、`phase3a-socket-results.json`、`phase3a-static-results.json`、`phase3a-*-regression.log`、`phase3a-flutter-analyze.log`。
环境沿用Python3.12.13、Pydantic2.6.0、FastAPI0.110.0，未安装依赖。

| 外部脚本 | SHA-256 |
| --- | --- |
| `phase3a_baseline.py` | `7d68069aa2b10ec14fbe15543df2b4e2b67fa4b179a6c69dd0a6379558ecdeec` |
| `phase3a_checks.py` | `a886ed743c9bac2e536bb79353233a9b3f0f15edd825c39f63fff22fbc19a937` |
| `phase3a_socket_checks.py` | `6cf3e16bc946ea5a5c7f779deb5b0c0c437c93714c564848ea127ad67f1489cd` |

既有回归脚本及哈希见 [2B记录](02b-hybrid-retrieval.md#复现)。

## 已知问题与未完成边界

- **已完成并验证**：本模块独立API、严格Schema、规则解析、携带式增量状态、显式更正／待确认、冲突、离线回归、Flutter静态分析与真实本地HTTP。
- **已完成但覆盖受限**：未测生产负载、Docker构建、跨客户端并发；无需依赖这些才能使用本地独立接口。真实模型和真机仍未验证。
- **规则局限**：只支持可明确解析的分句及有限词表；复杂中文、隐式预算、未支持参数、OR条件、自动理解“修改为”、广义同义词都可能追问。不把泛指降噪当ANC，也不将跑鞋放宽成所有运动鞋。没有实测整体槽位准确率。
- **原有问题，未扩大本次修改范围**：`GET /api/v1/knowledge/products/sample-shoe-01` 的 `parameters.waterproof.value` 实测为数值0.0，而不是false；内部目录事实仍是bool。已有回归主要检查值相等，Python中false与0.0相等，不能证明JSON类型正确。下一模块必须先修复旧知识参数HTTP类型并补充类型断言，再联调条件过滤。此次新需求接口已防止同类错误。
- **尚未完成**：将条件用于真实检索／硬过滤／软偏好排序、无候选解释、商品知识充分性判断、聊天／识别／Flutter接入、LLM辅助需求解析、Agent、会话持久化与长期偏好管理、80条独立评测。
- **旧链路风险仍在**：旧随机Mock、静默放宽与无证据报告未迁移；新接口上线不表示旧聊天已经完成受约束推荐。

## 回退与唯一下一步

没有数据迁移、会话格式变化或客户端修改。撤销本模块四个新增源码文件、main路由注册及对应文档即可回到2B能力。已推送历史只用反向提交，不强推或reset；未执行回退。

**唯一下一步：Phase 3B——先修复并验证旧知识API的布尔字段类型，再用完整样例事实消费结构化需求，实现硬约束过滤、集中配置的软偏好排序、分项得分及无候选原因；不得自动放宽条件。**
