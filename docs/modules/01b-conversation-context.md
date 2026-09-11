# Phase 1B：会话可靠性与识别上下文

日期：2026-09-11。前置版本：`c9500a95f82bb7ea049f092bcdf04a06a937313c`（Phase 1A）。
本记录只描述本模块的实际实现，不代表 Phase 1 或整个升级已完成。

## 目的与范围

修复会话路径输入、摘要解析／丢历史、当前消息重复，以及识别结果进入聊天后丢失的问题。
保留原有 API 路径和 Flutter 页面；没有新增依赖、部署、真实电商接口、向量库或大型框架。
按照用户要求，主仓库不新增测试文件／临时脚本，检查材料保存在仓库外。

## 修改文件

| 文件 | 改动 |
| --- | --- |
| `backend/app/models/schemas.py` | 安全会话 ID、ChatProduct、ChatRequest、ChatModelResult、ChatSummary、ChatResponse |
| `backend/app/services/sessions.py`（新增） | 版本化会话 Schema、旧格式校验、同会话锁、原子保存、资源限制与安全错误 |
| `backend/app/services/chat.py` | 普通／流式共用会话事务；保留完整历史；摘要失败回退；商品恢复与受控更新 |
| `backend/app/core/prompt_engine.py` | 不再截断摘要、不重复当前请求、标明历史角色和未知商品价格，移除虚构报价示例 |
| `backend/app/routers/chat.py` | 会话 HTTP 错误映射、流前检查、兼容终态错误、及时关闭生成器 |
| `android-app/lib/screens/result_screen.dart` | 传递包含人工修正的识别对象 |
| `android-app/lib/screens/chat_screen.dart` | 无价格／ID的商品上下文、识别来源提示、保留后端 action、报告报价检查、防止发送中重复点击 |
| `android-app/lib/services/api_service.dart` | 普通 POST 不再超时自动重发、会话友好错误、兼容终态错误处理、关闭每次流的 HTTP 客户端 |
| `README.md`、`backend/.env.example`、`docs/api.md`、`docs/architecture.md`、`docs/modules/README.md` | 当前能力、单进程启动、接口契约和限制说明 |

## 实际行为

### 安全与原子性

- API 和直接调用服务都校验 ID；保留合法旧 ID，拒绝路径字符、空 ID 和 Windows 设备名。
- 文件路径校验拒绝已有符号链接；该保护不能替代操作系统目录权限或防御恶意本地用户的竞态换链。
- 消息数组旧格式仍可读取；首次成功新回复才写入版本 2（包含完整 messages、summary、summarized_count、current_product）。
- 损坏历史不会视为“新会话”并覆盖，返回 409 且保留原文件。
- 同一个事件循环内，同一会话的请求从加载到保存串行；不同会话并行。锁等候 30 秒后返回忙碌错误。
- 写临时文件、flush/fsync、同目录原子替换，失败不假报保存成功。写入失败及流取消均检查了旧历史不被破坏。
- 文件 2 MB、最多 500 条历史和 Prompt 48,000 字符的资源保护；超限要求新建对话，不清理旧历史。

### 摘要与上下文

- 摘要使用明确 JSON Schema，不再要求纯文本后又当 JSON 解析。
- 超过 8 条未摘要历史时尝试摘要，保留最近 6 条；摘要失败保留历史，不静默裁剪。
- 成功摘要跨服务实例复用；完整原文始终保存，早期用户原文仍进入后续 Prompt，避免摘要漏掉预算／排斥条件。
- 当前用户消息只在当前请求位置出现一次；历史摘要不再标成助手或被二次切掉。
- 非流式回复和摘要有有限修复；流式最终结果不合法时明确失败、不保存半轮。

### 商品与客户端

- 识别详情页把用户修正后的识别信息带入聊天，首次显示来源提示；不为适配旧 Product 模型伪造 ID／0 元价格。
- 后续不传商品时从会话恢复；明确传新商品时替换。
- 模型输出的 current_product 不回写为事实。当前商品仍是客户端／识别上下文，尚未经过 RAG 证据核验。
- 缺少价格或平台时不调用价格相关报告入口；客户端不再凭关键词把后端 none 强行改成 report。
- 普通 POST 的超时自动重试已移除，但未加入幂等键，手工重复发送仍可能形成重复轮次。

## 实际验证

环境沿用已有 Python 3.12.13、FastAPI 0.110.0、Pydantic 2.6.0、httpx 0.26.0、Flutter 3.24.5。
测试全部使用临时目录和模型桩／MockTransport，不读取或改写用户真实会话，不调用真实模型。

| 检查 | 实际结果 |
| --- | --- |
| 新增 Phase 1B 检查，冻结前置 `c9500a9` | 29 项中 3 项通过、26 项未通过；含新模块不存在造成的错误，非模型质量指标 |
| 相同 29 项检查，升级后 | **29/29 通过**，退出码 0 |
| 原有阶段检查，排除明确留待 1C 的两项 | **30/30 通过**，含 1A 原有 27 项与本轮修复的 3 项 |
| 原有完整 Phase 1 检查 | **30/32 通过**，1 项断言失败＋1 项错误，退出码 1；没有改掉失败断言 |
| Python 内存 compile | 30 个后端源文件通过 |
| 静态交付检查 | Markdown 本地链接、基线／升级后检查脚本 SHA 一致、启发式凭据扫描、git diff --check 通过；主仓库无新增测试／脚本 |
| `flutter analyze --no-pub` | 两次运行均 No issues found，最后一次约 12 秒 |
| Dart 仓库外断言 | 人工修正的识别属性正确序列化，无 price／id 字段 |
| 真实本地 Uvicorn 进程 | `/health`、`/openapi.json` 可访问；普通／流式非法 ID 均 422；检查后进程已停止 |
| 接口／存储异常 | 409 坏历史、422 输入、503 原子保存失败、旧 SSE 终态错误与未保存、取消释放锁、异会话并行均覆盖 |

符号链接拒绝分支使用 mock 校验，没有创建需要额外 Windows 权限的真实符号链接。
29 项新增检查中的 Flutter 导航／请求传递是源码契约检查，不是 Widget／真机端到端测试；Dart 断言另行运行。

保留的两项失败：

1. `test_stream_emits_before_reply_closes`：旧解析器仍等到 reply 字符串闭合才能输出，保留逐字人为延迟。
2. `test_stream_timeout_has_error_and_end`：服务层尚无统一 error/end 事件；路由仅为已知错误提供旧格式兼容终态。

工程检查不是产品评测；未测真实识别率、推荐效果、真实首字延迟，80 条产品评测尚未建立。

### 材料与复现

本机材料目录：`D:\smart_price_ai-validation`（不在 GitHub 主仓库中，应单独保留）：

- `baseline-c9500a9.zip`、`baseline-c9500a9/`：本模块前置源码冻结快照。
- `phase1b_checks.py`、`phase1b-baseline-results.json`、`phase1b-results.json` 和对应日志。
- `phase1_checks.py`、`phase1b-progress-results.json`、`phase1b-regression-results.json` 和对应日志。
- `phase1b_recognition_check.dart`、`phase1b-local-server-results.json`、`phase1b-local-server-log.txt`。
- 最早冻结的 `baseline-d02b1d0/` 与 1A 的旧结果仍保留，可用于后续产品基线。

检查脚本 SHA-256（基线／升级后结果均记录）：

```text
phase1b_checks.py: cb5048be68808771d954fa290e386c43349bb8cc3e499b564a695c320f2438c0
phase1_checks.py:  c4f20e5061d3c76cb0c48980f6a161ec8eba93932965b5506ac6a750d3f1ef41
```

PowerShell 复跑（需要保留本机仓库外材料；只有 GitHub 源码不包含这些验证脚本）：

```powershell
Set-Location D:\smart_price_ai
$env:PYTHONIOENCODING='utf-8'
& .\backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1b_checks.py --output D:\smart_price_ai-validation\phase1b-rerun.json
& .\backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1_checks.py --output D:\smart_price_ai-validation\phase1-rerun.json
# 第二条完整阶段检查在本版本预期仍报告上述两项失败；不要据此宣称 Phase 1 完成。

$env:SMART_PRICE_SOURCE='D:\smart_price_ai-validation\baseline-c9500a9'
& .\backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase1b_checks.py --output D:\smart_price_ai-validation\phase1b-baseline-rerun.json
Remove-Item Env:\SMART_PRICE_SOURCE

& C:\flutter\bin\dart.bat --enable-asserts D:\smart_price_ai-validation\phase1b_recognition_check.dart
Set-Location D:\smart_price_ai\android-app
& C:\flutter\bin\flutter.bat analyze --no-pub
```

## 风险、回退与未验证项

- 已完成并验证：上文离线回归、后端输入与会话事务、Flutter 静态检查、识别序列化和本地启动。
- 已完成但环境限制未验证：真实模型摘要质量／识别后真实对话、Flutter 真机连续追问、Docker／平台构建。
- 尚未完成：完整 SSE 协议、RAG、结构化用户需求、确定性排序、证据报告、统一 Agent 状态、长期偏好管理及 80 条评测。
- 当前只有本地单进程会话锁，无账号授权／跨进程并发保证；不应当作生产多用户安全会话存储。
- 摘要保留原文避免丢失，但不能保证模型遵守原文；硬约束必须在后续确定性过滤中落地。
- JSON v2 对旧代码不向后兼容。回退前停止本地服务并**备份**整个会话目录；只回退本模块代码时，为旧版本使用独立的旧数据副本／新空目录，不把 v2 交给旧版读取。不要为回退直接删除当前历史。模块前置代码是 `c9500a9`；实际回退操作需另行确认。
- 没有安装新依赖、部署或接入任何真实电商／历史价格数据。

## 唯一下一步

**Phase 1C：统一 SSE 的文本增量、节点状态、最终结果、错误与结束事件，并同步 Flutter 解析、取消、超时和流结束处理。**
先保留当前两项失败作为基线，再补充分块／转义／网络中断回归，不改变已交付的会话事务边界。
