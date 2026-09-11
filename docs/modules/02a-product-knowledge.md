# Phase 2A：固定商品知识 Schema 与样例库

日期：2026-09-11。状态：已完成本模块实现、离线工程回归和真实本地 HTTP 验证；尚未接入检索／聊天／Flutter。
修改前基线：`8ec4b1a9c45eb7fc6afd8dcc635fa7cb3122cd6e`（Phase 1C）。本记录随模块提交；用 `git log -- docs/modules/02a-product-knowledge.md` 定位交付提交。

## 目的与范围

为后续 RAG、硬过滤和排序提供稳定、可验证的商品事实，而非在 Prompt 中生成商品属性。
保留 Flutter＋FastAPI 和旧接口，本模块只新增知识基础与三个可运行的只读 API，不声称完成整个 Phase 2。
没有安装依赖、迁移数据库、接电商、下载Embedding模型、引入Agent框架、部署或启动子代理。

审计发现 `comparison.py` 使用随机平台报价、运行时ID且可能在无匹配时放宽条件，不适合直接充当知识证据。
本模块没有把随机数据包装为可靠商品事实，也没有在未完成业务适配时贸然替换旧接口。

## 修改文件

| 文件 | 实际实现 |
| --- | --- |
| `.gitattributes` | 仅为商品库JSON固定LF，避免Windows自动换行转换改变文件SHA |
| `backend/app/models/knowledge.py` | ProductFacts／ProductKnowledge、参数、价格区间、来源、目录、查询及响应Schema |
| `backend/app/catalog/sample-products.v1.json` | 18条固定虚构商品，运动鞋／耳机／双肩包各6条，来源、证据ID和版本随代码保存 |
| `backend/app/services/knowledge.py` | 有界读取、重复键检查、完整校验、只读快照、ID查找、精确Metadata分页和证据字段提取 |
| `backend/app/routers/knowledge.py` | 新增商品列表、详情、证据三个只读API；422／404／503明确反馈 |
| `backend/app/main.py` | lifespan加载快照并注册新路由；知识文件失败不阻止其他接口启动 |
| `backend/.env.example` | 说明本地知识接口无需模型／数据库，文件更新需要重启；不新增环境变量 |
| `README.md` | 无模型本地验证命令和当前集成边界 |
| `docs/api.md`、`docs/architecture.md` | Schema、证据身份、数据生命周期、错误约定与未完成能力 |
| `docs/modules/README.md`、本文 | 进度、验证、风险、回退与下一步 |

## 数据与证据规则

- `dataset_id = smart-price-synthetic-v1`，`revision = 2026-09-11.1`，`schema_version = 1`。
- 商品、品牌、型号、参数、价格、优缺点全部是**虚构工程设定**，不是商家／厂商／网络资料。`source.kind = local_synthetic`。
- 每个商品带 `data_kind = sample`，所有成功响应带固定的样例声明。证据只能证明“文件中有此设定”，不能证明真实商品事实。
- 商品必备名称／品类／品牌／型号、参数、价格区间、场景、优缺点、排斥条件、建议、来源与证据ID。
- 参数有明确label、标量value和可选unit；`null`代表未知，不能填为0／false／支持。单耳重量与头戴整机重量使用不同键。
- 非有限数、价格字符串／布尔值、反向价格区间、未知字段、空白必填文本、重复ID、缺失来源、无效编码、重复JSON键均拒绝。
- 价格是CNY样例区间，不是实时最低价。排斥条件是商品不适用情形，不是用户长期偏好。
- `ProductCatalog` 从固定包内路径加载，读取上限2,000,000字节；目录条数上限5000，当前18条，未做规模性能评测。
- 每进程一次加载，不热更新；返回深拷贝，调用方不能污染快照。原始字节SHA-256标识实际文件内容；`.gitattributes`仅为商品JSON固定LF，避免跨平台检出改变哈希。
- `evidence_id → product_id → fields` 来自同一份校验后事实；证据同时返回source、`/products/N` JSON Pointer及版本／SHA，不依赖第二份重复文案。
- 证据ID需与版本及哈希共同保存；更新数据应增加revision，重启后生效，旧证据通过Git历史定位，不提供历史查询API。

当前样例文件SHA-256：`994d9a90d7d19f58c2e09102654d770ff29f9c49e4853bf25f94a5cb9f76951c`。

## API 与运行

- `GET /api/v1/knowledge/products`：可选category／brand精确筛选，默认limit20、最大100，offset从0开始；按product_id稳定排序，total为分页前匹配数。
- `GET /api/v1/knowledge/products/sample-shoe-01`：商品详情及当前数据快照身份。
- `GET /api/v1/knowledge/evidence/ev-shoe-01`：商品事实、合成来源、定位及快照身份。

筛选无匹配返回空数组，不静默放宽；非法输入422，ID不存在404，目录不可用503。错误不暴露本地路径和校验原文。
目录不可用仍能访问health，识别／聊天按原配置工作；不能用health200证明知识库就绪。

从 `backend` 运行 `uvicorn app.main:app --host 127.0.0.1 --port 8000` 后即可访问上述接口。
本次真实HTTP检查从临时工作目录用 `--app-dir` 启动，未设置模型密钥、Redis和PostgreSQL，也能查询商品和证据。
现有Dockerfile的 `COPY app/ ./app/` 已覆盖样例文件，故未改Dockerfile；本次未构建镜像。

## 实际验证

使用既有Python 3.12.13、Pydantic 2.6.0、FastAPI 0.110.0环境，未安装依赖。
所有测试／临时验证脚本和结果位于仓库外 `D:/smart_price_ai-validation`，没有在主仓库新增test文件或脚本。

| 检查 | 实际结果 |
| --- | --- |
| 修改前接口基线 | health200，新知识列表／详情／证据均404；新检查首次因模块尚不存在而ImportError；最终审查新增LF约束检查先失败，修复后通过 |
| Phase 2A Schema、目录和ASGI检查 | **31/31**；覆盖错误文件、ID/来源、参数、未知值、精确筛选、分页、证据定位、不可变副本、快照重载与失败隔离 |
| 原Phase 1检查 | **32/32**，原脚本未修改 |
| Phase 1B的既有v1契约适配版 | **29/29**，本模块未修改该脚本 |
| Phase 1C后端检查 | **35/35**，原脚本未修改 |
| 后端源文件内存compile | **34个通过** |
| `flutter analyze --no-pub` | **No issues found**；本模块没有修改Flutter代码 |
| 真实localhost Uvicorn＋HTTP | 列表18条、耳机筛选6条、分页2条、详情／证据一致、404／422、OpenAPI、无模型/数据库启动及工作目录独立性通过；临时进程已停止 |

这些工程套件有重叠，不能相加冒充独立业务样本；18条商品也不是18条评测问题。未产出Recall@5、推荐有据率、80条产品评测或真实模型首字指标。

### 复现命令

```powershell
Set-Location D:\smart_price_ai
$env:PYTHONIOENCODING='utf-8'
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase2a_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase2a_socket_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1_checks.py --output D:\smart_price_ai-validation\phase2a-phase1-results.json
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1b_v1_checks.py --output D:\smart_price_ai-validation\phase2a-context-results.json
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1c_checks.py
Set-Location D:\smart_price_ai\android-app
& C:\flutter\bin\flutter.bat analyze --no-pub
```

基线结果 `phase2a-baseline-results.json`；当前结果 `phase2a-results.json`、`phase2a-socket-results.json`、`phase2a-phase1-results.json`、`phase2a-context-results.json`、`phase2a-stream-results.json`；汇总 `phase2a-delivery-checks.json`，各检查日志同目录。
`phase1c_checks.py`仍写它原来的结果路径，本次将真实复跑结果复制为 `phase2a-stream-results.json`，没有修改原检查。
这些文件是本机材料，不随GitHub仓库上传；异地复现要另行保留／交付验证目录，不能仅凭克隆主仓库复跑这些检查。

| 外部检查脚本 | SHA-256 |
| --- | --- |
| `phase2a_checks.py` | `4070b395efdbd53ede25b025c51e076d72dd20a66c13a1445265bcaa42047c13` |
| `phase2a_socket_checks.py` | `01231b8e16e0d33030dc40b7465562f88e5d1062840efcc0ab66e74d15e94a99` |
| `phase1_checks.py` | `c4f20e5061d3c76cb0c48980f6a161ec8eba93932965b5506ac6a750d3f1ef41` |
| `phase1b_v1_checks.py` | `e53a9a514f0f5040cf2400b4f35e915e5757c797adf2c62d1f64de107d1cd3c4` |
| `phase1c_checks.py` | `0f2ca76779dcfc47ae36fc492027de9f03164ff881cdd812806465c76ad87188` |

## 验证边界与剩余风险

- **已完成并验证**：固定样例、Schema、精确Metadata查询、证据字段与文件追溯、加载失败隔离、旧工程回归与真实本地HTTP。
- **已实现但环境验证未覆盖**：Docker镜像内文件分发仅核对COPY规则，未实际构建。真实模型、Flutter真机未测；本模块不涉及模型调用和新前端交互。
- **尚未完成**：语义切片、关键词／向量索引、混合召回／Rerank、识别实体与知识商品匹配、聊天／Flutter／旧比价接入、需求解析、硬软排序、工作流、偏好、80条产品评测。
- **旧流程风险仍在**：随机Mock、旧筛选的静默放宽及无证据报告没有在本模块改写；不得宣称它们已获得新目录的确定性和证据保障。
- **数据覆盖有限**：仅3品类、18条虚构商品；真实品牌／型号可能完全无匹配。之后必须明确空检索和知识不足，不得伪造真实商品对应关系。

## 回退与唯一下一步

本模块不迁移数据库或会话。若需回退，撤销本模块新增知识文件、路由注册与lifespan加载，原Phase 1接口和会话格式不变。
已推送历史用反向提交处理，不reset／强推；未实际执行回退。

**唯一下一步：Phase 2B——以本固定快照为语料，实现语义字段切片、Metadata、关键词与轻量向量召回、候选融合及Rerank，并让每条命中携带商品ID、证据ID、相关字段和匹配原因。**
