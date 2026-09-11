# Phase 1C：SSE 协议与流式消费

日期：2026-09-11。状态：已完成本模块实现、离线回归和本地 HTTP 模型桩验证；真实模型／真机未验证。
修改前基线：`e1f18487baca0ea8ba536f3ddff7ed2df9742e95`（Phase 1B）。本记录随模块代码提交；交付提交可用 `git log -- docs/modules/01c-streaming-protocol.md` 定位。

## 目的与范围

保留 Flutter＋FastAPI、现有 `/api/v1/chat/stream` 请求字段和 Phase 1B 会话事务边界。
修复两项已复现缺陷：正则必须等回复结束引号才能发首段文字；TimeoutError 直接逸出，没有 error/end。
不改写整个购物流程，不新增依赖，不接真实电商，不将模型桩延迟写成真实模型指标。

## 修改文件与实现

| 文件 | 实际变化 |
| --- | --- |
| `backend/app/core/streaming.py` | 新增 Pydantic 五类事件，增量读取顶层 reply；处理嵌套字段、转义、换行、分块 Unicode 与代理对，最终拒绝重复 JSON 键 |
| `backend/app/core/llm_client.py` | 上游按 SSE 完整帧处理；校验 choices/delta/结束原因，缺少 stop 或 DONE、格式错误、截断与工具调用明确失败 |
| `backend/app/services/chat.py` | context/model/validation/save 状态，delta/result/error/end；移除 15ms 人为延迟；单轮处理预算；保持完整校验后保存，取消释放锁 |
| `backend/app/routers/chat.py` | 发送 event/id/data，保留已有请求与预检错误，增加 no-cache 与禁代理缓冲响应头 |
| `backend/app/config.py`、`backend/.env.example` | `CHAT_STREAM_TIMEOUT_SECONDS` 默认120秒、最大180秒；复用现有 HTTP 池与空闲超时 |
| `android-app/lib/services/chat_stream_decoder.dart` | 新增纯 Dart 完整帧／事件校验，支持旧格式；只有 result＋成功 end 才算完成 |
| `android-app/lib/services/api_service.dart` | 状态回调、连接／空闲／总计时限、错误与缺失终态处理、页面级取消、至多一次完成或错误回调 |
| `android-app/lib/screens/chat_screen.dart` | 复用已有聊天页，显示真实执行状态；早期保存返回会话ID，退出页面取消请求 |
| `README.md`、`docs/api.md`、`docs/architecture.md`、`docs/modules/README.md` | 更新现状、兼容边界、配置与后续顺序；本文件记录交付 |

协议详见 [API](../api.md#sse-v1-事件协议)，架构详见 [当前架构](../architecture.md)。
`version=1`，每请求 seq 从1连续递增。不是恢复游标，不提供自动重放。

## 关键取舍

- `delta` 是临时文本，不能直接当报告或成功轮次。最终 JSON、唯一键、回复一致性和 Schema 都通过才保存。
- 与非流式 JSON 修复不同，流式不自动重试／盲修 JSON，避免已经显示的文字与重试回复混合。失败明确提示，不伪造完整结果。
- 保留旧 `reply/done` 字段，Phase 1B 客户端可读新服务。新客户端可读无 type 的旧服务，但旧模式没有 v1 的序号与完整性保证。
- 保存与网络送达不是一个事务：保存后断流，服务端可能已存完整轮次。客户端只提示“未能确认”，不承诺回滚，也不自动重发。
- 取消关闭响应与生成器，不关闭应用共用的连接池。仅保存前取消可保证本轮未保存。
- 客户端帧长度限制按**单帧**计算，不累计所有小 delta 的协议开销，避免正常长回复被误判超限。
- 仍使用单进程文件会话；本模块不是鉴权、幂等性、长期偏好或完整 Agent 工作流升级。

## 实际验证

环境沿用后端 Python 3.12.13、Flutter 3.24.5／Dart 3.5.4。没有安装依赖。
所有验证脚本、测试与结果放在 `D:/smart_price_ai-validation`，主仓库没有新增 test 文件或临时脚本。

| 验证 | 实际结果 |
| --- | --- |
| 修改前原 Phase 1 工程检查 | 30/32，1失败＋1错误，正是提前输出和超时终态两项 |
| 修改后原 Phase 1 检查（原脚本未改） | **32/32** |
| 新增 Phase 1C 后端检查 | **35/35** |
| Phase 1B 会话回归（v1 协议适配版） | **29/29** |
| 独立 Dart 解码器检查 | **26/26**，含每个字节切分位置、LF/CRLF、多行data、旧格式、错误优先、缺失end、乱序、文本不一致、5000单字增量 |
| 后端源文件内存 compile | **31个通过**，不生成测试文件 |
| `flutter analyze --no-pub` | **No issues found** |
| 本地真实 Uvicorn＋HTTP 流 | 成功、超时错误、客户端断开后同会话再用均通过；health、OpenAPI通过 |

上述套件覆盖有重叠，不相加冒充独立业务样本数量，也不是80条产品评测。
后端新增检查覆盖最终结构失败不落盘、原子写失败、总预算超时、准备阶段超时、任务取消、生成器关闭、嵌套reply、重复键、无效转义、上游缺失DONE／stop、内容过滤和工具调用失败。
还使用 httpx MockTransport 检查真实传输解析路径的逐字节UTF-8、ReadTimeout安全映射及取消只关响应不关共享池；未请求真实模型。

Phase 1B 原脚本完整保留为 `phase1b_checks.py`。新 `phase1b_v1_checks.py` 只适配四处契约检查：结果不再是最后一个事件、error后追加end、服务错误从抛异常改为事件、Flutter错误判断转入新解码器。商品保持、旧历史、锁和保存断言没有放宽；这是协议变更，不伪称旧断言原样通过。

### 本地首段传输证据（不是实测模型首字指标）

本地模型桩故意在首段后等待350ms；HTTP消费者在会话文件尚未保存时收到首段，再收到终态。
本次提交前复跑成功流首个 delta 为 0.009544s，结束为 0.379137s；这些仅证明本地管道没有等整段回复，不代表真实模型速度。临时服务已停止。

### 复现命令

```powershell
Set-Location D:\smart_price_ai
$env:PYTHONIOENCODING='utf-8'
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1_checks.py --output D:\smart_price_ai-validation\phase1c-phase1-results.json
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1c_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1b_v1_checks.py --output D:\smart_price_ai-validation\phase1c-context-results.json
& C:\flutter\bin\dart.bat D:\smart_price_ai-validation\phase1c_decoder_checks.dart
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1c_socket_checks.py
Set-Location D:\smart_price_ai\android-app
& C:\flutter\bin\flutter.bat analyze --no-pub
```

基线结果 `phase1c-baseline-results.json`；修改后结果 `phase1c-phase1-results.json`、`phase1c-results.json`、`phase1c-context-results.json`、`phase1c-dart-results.json`、`phase1c-socket-results.json`，对应日志同目录。
这些材料是本机路径，不随应用仓库上传；换机复现须另行保留／交付验证目录，单独克隆主仓库无法运行这些检查。

脚本 SHA-256：

| 脚本 | SHA-256 |
| --- | --- |
| `phase1_checks.py` | `c4f20e5061d3c76cb0c48980f6a161ec8eba93932965b5506ac6a750d3f1ef41` |
| `phase1c_checks.py` | `0f2ca76779dcfc47ae36fc492027de9f03164ff881cdd812806465c76ad87188` |
| `phase1b_v1_checks.py` | `e53a9a514f0f5040cf2400b4f35e915e5757c797adf2c62d1f64de107d1cd3c4` |
| `phase1c_decoder_checks.dart` | `dfa4429e77d6a517e7fdcb43ffda198288355525f558be171978b99aea80c3f4` |
| `phase1c_socket_checks.py` | `e9ca65e09198ad84921e0c3740c5df7f12b65cf6051f4a70c7911b854f9c1f8f` |

## 验证边界与尚存风险

- **已完成并验证**：上表工程行为、协议解码、源代码静态分析与本地模型桩网络流。
- **已实现但未进行真实环境验证**：真实火山模型 stop/DONE 兼容性、真实网络与代理的流行为、Flutter真机页面销毁和显示效果。独立Dart检查不是Widget或真机测试；未构建Docker镜像／APK，未部署。
- **尚未完成**：可追溯商品库RAG、需求硬软约束、确定性排序、单Agent状态、长期偏好、80条独立产品评测；旧 action_data 仍是字典，不能证明推荐事实可靠。
- **后续工程风险**：无请求幂等键、会话历史查询或账号归属校验；不支持多worker共享文件。跨网络“恰好一次”和真正的模型首字指标未解决。

## 回退与唯一下一步

前后端一起回退本模块代码至基线 `e1f1848` 对应版本；本模块不迁移数据，Phase 1B 的版本2会话仍可读。
已推送历史不使用 reset／强推；若需要撤销，用后续反向提交并重新验证。这里仅说明方案，未执行回退。

**唯一下一步：Phase 2A，统一商品知识 Schema 与可追溯本地样例库，作为后续混合检索与证据推荐的基础。**
