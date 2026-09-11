# Phase 1A：识别基础链路与模型客户端

日期：2026-09-11。状态：本模块已完成离线验证；**整个 Phase 1 尚未完成**。
升级前 Git 基线：`d02b1d0185a1edfad2c70c88771486aab981fb28`。

## 目的与实现范围

修复单／多目标缓存冲突、dHash 误命中、多目标不写缓存和模型失败假装空结果；
统一后端模型 HTTP 连接池生命周期，并为识别输出增加 Pydantic 校验与有限修复。
保留现有 Flutter 页面、API 路径、JSON 成功响应形状和原有单目标两阶段降级；没有引入新业务依赖。

| 文件／模块 | 实际改动 |
| --- | --- |
| `backend/app/core/base_api_client.py` | 集中连接池工厂、分项超时、安全错误、非流式 provider envelope 校验；支持显式注入和独立客户端关闭 |
| `backend/app/core/dependencies.py`、`app/main.py` | 应用 lifespan 持有连接池，LLM/VLM 请求依赖借用同一池 |
| `backend/app/core/llm_client.py`、`vlm_client.py` | JSON 围栏与对象／数组兼容、Schema 校验、有限修复；VLM 复用统一响应解析；流传输关闭上游资源 |
| `backend/app/services/recognition.py` | 图片合法性与方向校验；SHA-256 精确缓存，模式／模型／版本隔离，原子写入，坏缓存忽略；多目标不再吞掉模型错误 |
| `backend/app/models/schemas.py` | 识别名称／品类非空，中心点嵌套 Schema 校验有限数值 0–1；校验后兼容旧 bbox 转换 |
| `backend/app/routers/{recognize,chat,filter,report,suggest}.py` | 注入共享客户端，映射安全模型错误；不改变原业务服务流程 |
| `backend/app/middleware/error_handler.py` | 不记录原始异常内容和堆栈，保留方法与异常类型 |
| `backend/app/config.py`、`.env.example` | 配置连接池、连接／读取／写入／池等待超时及修复次数 |
| `backend/docker-compose.yml` | 传递已有模型 ID 和新增可选客户端参数；数据库架构未改造 |
| `README.md`、`docs/api.md`、`docs/architecture.md`、`docs/modules/` | 更新事实边界、运行方式、API、架构、验收及下一步 |

## 关键决策

- 精确缓存优先正确性，不再承诺重新拍照／相似图片命中。旧缓存保留但不读取，不自动删除用户数据。
- 缓存 TTL 仍为 7 天。原子文件替换避免半写；写失败只跳过缓存，不丢当前识别结果。
- 通用 JSON 默认 1 次修复，最大配置 2 次；只有解析／Schema 失败才修复，不重试网络、超时或鉴权错误。
- 单目标输出失败仍可两阶段降级，默认最多 5 次模型调用；多目标默认最多 2 次。失败明确返回错误，不造商品。
- 接口保持现有成功形状；识别无效图片返回 422、模型超时 504、上游／输出错误 502。
- 主仓库不新增测试文件或临时脚本；验证放仓库外。此选择降低仓库自包含的验证能力，不能隐瞒。

## 实际验证

环境：Windows；Python 3.12.13；现有 FastAPI 0.110.0、Pydantic 2.6.0、httpx 0.26.0；Flutter 3.24.5。
后端隔离环境为 `backend/.venv`，只安装现有 requirements 中的依赖，没有安装 pytest 或新业务包。

| 检查 | 实际结果 |
| --- | --- |
| 修改前原始离线工程基线 | 12 项中 1 通过、9 断言失败、2 错误；基线退出码 1 |
| 扩展模块检查跑冻结旧源码 | 27 项中 3 通过、24 项未通过；包含新增接口／能力不存在导致的错误，并非模型质量指标 |
| 同一份扩展检查跑本模块 | **27/27 通过**，退出码 0 |
| 完整 Phase 1 工程检查 | **27/32 通过**，4 项断言失败、1 项错误，退出码 1；不将其描述为全阶段通过 |
| 兼容接口 smoke | MockTransport 下单／多识别、chat、filter、suggest、report 成功响应；health、本地 compare 和 trend 通过；不是外网或真机验证 |
| 错误路径 | 多目标输出错误→502、上游 HTTP 错误→502、超时→504、非法图片→422；错误正文不包含模拟的上游私有原文 |
| 缓存／校验 | 单多隔离、黑白碰撞、版本与模型变化、空结果缓存、TTL／坏缓存、写失败与临时文件清理、坐标／bbox、图片模式与尺寸通过 |
| HTTP 生命周期 | 应用池共享和关闭、独立池创建与关闭、借用池不误关、底层流提前关闭通过；SSE 应用层取消／结束语义仍待修复 |
| `python -m pip check` | `No broken requirements found.` |
| 内存编译全部后端 Python 源文件 | 29 个文件通过，不把语法检查等同类型检查 |
| `flutter analyze --no-pub` | `No issues found!`；本模块未改 Flutter 源码 |
| Compose YAML／环境变量映射、Markdown 相对链接、检查文件 SHA | 均通过；没有执行 Docker 构建 |
| `git diff --check` 与变更文本凭据模式扫描 | 通过，未发现匹配；启发式扫描不等于完整安全审计 |

曾出现新增兼容 smoke 使用空 `best_choice` 导致旧报告 Prompt 的 KeyError；
核对既有调用协议后改为实际有效的样例商品输入，重新通过。空字典校验缺口仍记录为待解决，不借本模块扩大报告改造。
新增 Settings 字段最初触发 Pydantic `model_` 命名空间告警，限定 Settings 保留命名空间后重跑无该告警。

## 仓库外复现材料与命令

本机目录：`D:\smart_price_ai-validation`，不上传主仓库。

- `baseline-d02b1d0.zip` / `baseline-d02b1d0/`：修改前冻结源码。
- `environment-lock.txt`：实际已安装依赖 freeze。
- `phase1_checks.py`：标准库 unittest、隔离临时会话／缓存、MockTransport／AsyncMock 模型桩。
- `baseline-results.json`：原始 12 项基线；不覆盖。
- `module1-baseline-results.json`、`module1-results.json`：同一扩展检查分别运行旧源码与本模块。
- `phase1-progress-results.json`：完整 32 项阶段检查；对应 `*-log.txt` 保存实际失败详情。

当前检查文件 SHA-256：`c4f20e5061d3c76cb0c48980f6a161ec8eba93932965b5506ac6a750d3f1ef41`。计数以测试方法为单位；原始 failures/errors 可能包含多个 subtest，不能直接相减得通过数。JSON 的 `passed` 使用失败方法去重计数。

```powershell
# 在 D:\smart_price_ai 中执行；检查材料是本机外置文件，并非克隆仓库自带
$env:PYTHONIOENCODING='utf-8'
$python='D:\smart_price_ai\backend\.venv\Scripts\python.exe'
$checks='D:\smart_price_ai-validation\phase1_checks.py'
$only='cache,coordinate,hash,bad_json,multi_failure,schema_repair,json_array,invalid_image,empty_multi,center_missing,lifespan,transport_errors,owned_client,recognition_http,legacy_nonrecognition,stream_transport,legacy_bbox,single_two_stage,health,owned_pool,image_modes'

# 升级前：预期仍有失败
$env:SMART_PRICE_SOURCE='D:\smart_price_ai-validation\baseline-d02b1d0'
& $python $checks --only $only --output D:\smart_price_ai-validation\module1-baseline-results.json
Remove-Item Env:\SMART_PRICE_SOURCE

# 当前模块：27 项通过
& $python $checks --only $only --output D:\smart_price_ai-validation\module1-results.json

# 整个 Phase 1：当前仍有 5 项失败，不应视为通过
& $python $checks --output D:\smart_price_ai-validation\phase1-progress-results.json
```

这不是 80 条产品评测；尚无意图准确率、槽位准确率、Recall@5、推荐有据率或真实首字延迟结果。
冻结旧源码用于后续按统一样本补跑质量基线，不能把现在的桩通过率冒充模型／推荐指标。

## 未验证、风险与剩余任务

- 真实模型、真实网络、真机、Docker／Xcode 构建未验证；未部署。
- 会话 ID 仍可路径越界；摘要失败会丢早期需求，成功摘要也可能被后续 Prompt 截断。
- SSE 仍等待 reply 完整闭合才输出，缺 error/end；Flutter 尚未更新状态和友好错误。
- 本模块仅识别专用 Schema 收紧，其余业务宽泛字典与商品证据边界仍待升级。
- 同图并发请求未去重；过期缓存不会主动清理，总容量限制未实现。
- 传输超时为分项／分块空闲时间，不是整个多阶段请求的墙钟总时限；降级调用有额外延迟和费用。
- Redis／PostgreSQL 可选化 Compose、RAG、需求排序、Agent State、长期偏好和 80 条评测尚未完成。

## 回退与唯一下一步

本模块为清理提交之后的独立增量，不涉及数据库迁移。需要回退时对本模块提交做普通 revert，经用户授权后提交／推送；不要 reset 或强推。旧缓存未删除，精确缓存文件不会影响原版本读取路径。

**唯一下一步：Phase 1B——修复会话 ID 安全、摘要保留与识别商品上下文传递，并用仓库外回归独立验收。**
