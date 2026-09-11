# API：当前实现与兼容边界

更新：2026-09-11，Phase 1A–1C。以运行时 `/openapi.json` 和 `/docs` 为接口 Schema 权威来源。
本页不是完整升级验收报告，商品与价格仍为本地样例。

## 已有接口（没有改名）

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET | `/health` | 进程健康，不代表模型配置可用 |
| POST | `/api/v1/recognize` | 单目标识别 |
| POST | `/api/v1/recognize/multi` | 多目标识别 |
| GET | `/api/v1/suggest` | 建议卡片 |
| GET | `/api/v1/compare` | 本地样例商品对比 |
| POST | `/api/v1/filter` | 解析筛选条件 |
| GET | `/api/v1/trend/{product_id}` | 模拟趋势，非真实历史价格 |
| POST | `/api/v1/report` | 原有报告生成，尚未实现证据检索 |
| POST | `/api/v1/chat` | 校验回复并持久化会话的 JSON 对话 |
| POST | `/api/v1/chat/stream` | SSE v1 五类事件，保留旧 `reply/done` 字段 |

## 识别请求与响应

两个识别接口均接收 `{"image_base64":"<图片的原始 Base64，不含 data URL 前缀>"}`。
请求字符串长度为 1–15,000,000；内容必须为有效图片，解码尺寸上限 20,000,000 像素。
识别前按 EXIF 旋转，统一 RGB、最长边 600px、JPEG 质量 75%；不发送原 EXIF。

单目标响应字段保持 `name/brand/category/color/material/style`。`name` 和 `category` 去除首尾空白后不能为空；无法确认的可选属性为空字符串，不凭规则补造商品信息。

多目标响应保持 `{"objects":[...]}`。对象含 `name/brand/category/color/center`，`center` 必须是包含 `x/y` 的对象，两坐标均为有限数值且在 0–1 内。模型返回旧版归一化 `bbox`（x/y/w/h）时，先校验边界再转换中心点。缺失或非法坐标不再伪造为 `(0,0)`。

只有模型给出通过校验的空数组时，接口才返回 `objects=[]`；模型错误不再伪装成“没有商品”。

## 错误与重试

识别图片内容无效：422，`detail` 为中文提示；请求字段 Schema 错误仍使用 FastAPI 422 格式。
模型读取超时：504；模型 HTTP／连接失败或输出不合格：502。响应仅包含安全提示，不返回上游响应、密钥或堆栈。
这些模型错误同样在普通 chat/filter/report/suggest 请求中映射；已发送响应头后的失败通过 `error` + `end(success=false)` 返回（取消或连接已断开时不能保证送达），保留兼容字段 `done=true,error=中文提示`。

`LLMClient.chat_json` 默认首次生成 + 最多 1 次格式／Schema 修复，设置范围为 0–2 次修复。
支持完整 JSON 对象／数组以及 Markdown JSON 围栏；不使用 eval、不盲目补引号或商品字段。
有 `response_model` 时返回 Pydantic 校验值，否则保持原有 dict/list 返回。
网络、鉴权、超时不会自动重试；上游 envelope 不合法直接报错，不进入该 JSON 修复循环。

单目标仍保留原有“视觉描述 → JSON 提取”降级，但只在输出错误时触发。
默认最坏调用次数为 5 次（直接识别 2 + 视觉描述 1 + 提取 2），配置修复次数为 2 时最多 7 次。
多目标不走两阶段降级，默认最多 2 次。修复不能保证成功；失败明确返回错误。

## 连接池配置

| 环境变量 | 默认 | 含义 |
| --- | --- | --- |
| `MODEL_CONNECT_TIMEOUT_SECONDS` | 10 | 建立连接超时 |
| `MODEL_READ_TIMEOUT_SECONDS` | 60 | 单次分块读取空闲超时，不是整段 SSE 总时限 |
| `MODEL_WRITE_TIMEOUT_SECONDS` | 30 | 写入超时 |
| `MODEL_POOL_TIMEOUT_SECONDS` | 10 | 等待池中连接超时 |
| `MODEL_MAX_CONNECTIONS` | 20 | 每进程最大连接数与 keepalive 数 |
| `MODEL_JSON_REPAIR_ATTEMPTS` | 1 | 非流式 JSON 格式／Schema 修复次数，0–2 |
| `CHAT_STREAM_TIMEOUT_SECONDS` | 120 | 流式上下文准备＋模型读取预算，最大 180 秒，锁等待另计 |

应用启动时创建共享 `httpx.AsyncClient`，通过请求依赖注入给 LLM/VLM，关闭应用时关闭池。
独立 Python 调用者若自行构造客户端，应使用 `async with LLMClient(...)` 或显式 `await client.aclose()`；借用外部 HTTP 客户端时，借用方不会关闭外部池。

## 对话请求与商品上下文

普通与流式接口共用请求 Schema；已有路径、`message/session_id/current_product` 字段不改名：

```json
{
  "message": "预算500元，不要皮革，适合通勤吗？",
  "current_product": {"name": "识别到的鞋", "category": "运动鞋", "material": "织物"}
}
```

- `message`：1–4000 字符，不允许全空白。
- 首轮可省略 `session_id` 或传 null，由服务生成 UUID；后续携带返回 ID。允许 1–64 位 ASCII 字母、数字、下划线、连字符且首位为字母或数字，拒绝 Windows 保留设备名。空字符串不再当成新会话。
- `current_product` 为可选 `ChatProduct` 对象；非空时 `name` 必填且去除首尾空格后非空。可选字段含 `id/brand/category/color/material/style/price/platform/rating/tags/image_url/original_price`。
- 识别商品无需价格／ID；价格缺失与 0 元不同。价格字段须有限、非负数，布尔值或数字字符串不接受；评分 0–5。未知扩展字段忽略，不写入会话。
- 兼容 Flutter 的 `imageUrl/originalPrice` 输入别名，输出采用下划线命名。可选字段长度／数量限制见 OpenAPI。
- 未传商品或传 null：继续使用当前会话商品；传新对象：替换商品。本模块未提供“清空商品”操作，可新建会话。
- 商品上下文来自客户端或识别，尚未经本地知识库核验，不能作为推荐证据。

普通成功响应仍含 `reply/action/action_data/session_id`，新增可选 `current_product`；无商品时普通响应省略该字段，流式终态为 null。
`reply` 必须为非空字符串，最长 16,000 字符；action 限定 `none/report/trend/filter/compare`，action_data 必须为对象（其各业务子结构尚待后续严格约束）。
非流式回复和摘要采用有限 Schema 修复；流式最终 JSON 进行 Schema 校验，不合格时本轮不保存，暂不对已显示流内容自动重播。
模型输出的商品字段不作为会话更新来源；只有明确传入的新商品才会替换上下文。

### 会话错误

| 状态 | 含义与行为 |
| --- | --- |
| 422 | 请求字段无效，模型未调用 |
| 409 | 历史损坏、不支持的版本、危险文件路径或同会话仍忙；原文件保留 |
| 413 | 会话／上下文达到保护上限；要求新建对话，不删除历史 |
| 503 | 读取或原子保存失败；原历史不被部分覆盖 |
| 502/504 | 模型错误／超时；本轮不追加记录 |

在发出 SSE 响应头之前可以发现的坏历史返回 HTTP 409/413/503；无效请求返回 422。
普通 POST 超时不自动重试，避免服务端其实已保存但客户端再次发送；尚未实现请求幂等键，手动重试仍可能重复。

## SSE v1 事件协议

路径和请求字段不变。响应类型 `text/event-stream`，设置 `Cache-Control: no-cache` 与 `X-Accel-Buffering: no`。
每帧由空行结束；`event` 对应 JSON 的 `type`，`id` 对应 `seq`。所有 JSON 事件先经过后端 Pydantic 校验。
`version=1`；`seq` 从 1 连续递增，仅在本次请求内有效；同一流中 `session_id` 不变。不是可恢复的事件日志，不支持 Last-Event-ID 重放。

| type | 专用字段 | 含义 |
| --- | --- | --- |
| `status` | `node`, `status="running"`, `message` | 当前执行状态；现有节点为 context/model/validation/save，不冒充尚未实现的 RAG 节点 |
| `delta` | `reply` | 新到达的临时文字，保留换行／转义字符／Unicode；不是完整结果 |
| `result` | `reply`, `action`, `action_data`, 可选 `current_product`, `done=true` | 已校验且已保存的完整结果；客户端仍等待 end 确认协议结束 |
| `error` | `code`, `error`, `done=true`, `reply=""`, `action="none"`, `action_data={}` | 安全错误提示，不包含模型原始异常；不得当作成功结果 |
| `end` | `success` | 成功时前一个事件为 result；失败时前一个事件为 error |

简化成功示例（省略其他 status 帧，但序号连续）：

```text
event: status
id: 1
data: {"version":1,"type":"status","seq":1,"session_id":"example-session","node":"model","status":"running","message":"正在生成回复"}

event: delta
id: 2
data: {"version":1,"type":"delta","seq":2,"session_id":"example-session","reply":"请补充预算。"}

event: result
id: 3
data: {"version":1,"type":"result","seq":3,"session_id":"example-session","reply":"请补充预算。","action":"none","action_data":{},"done":true}

event: end
id: 4
data: {"version":1,"type":"end","seq":4,"session_id":"example-session","success":true}

```

### 错误、取消与保存边界

- 模型 HTTP 读取仍使用连接池的空闲时限；`CHAT_STREAM_TIMEOUT_SECONDS` 默认 120 秒，最大 180 秒，涵盖获得会话锁后的上下文准备与模型分块读取，保存前再检查截止时间。同会话锁等待另有 30 秒上限；同步本地磁盘操作不是可硬中断的异步任务。
- 后端超时：`error.code=stream_timeout`（整轮预算）或 `model_timeout`（模型 HTTP 超时）。格式／截断：`model_output_invalid`；会话错误保留 `SESSION_*` code；未知异常 `stream_failed`。随后发 `end(success=false)`。
- 上游必须返回完整 SSE 帧、`finish_reason="stop"` 与 `[DONE]`；缺少终态、无效 JSON、长度截断、内容过滤或未支持的工具调用均明确失败，不静默跳过。
- 流式 JSON 不盲补引号、不自动模型修复或重放。与非流式 JSON 修复不同，已展示文本后重试可能产生重复或矛盾内容；失败由用户决定是否重新提问。
- `delta` 不写会话。完整 JSON、唯一键、reply 文本一致性和 Schema 校验后才原子保存。取消在保存前发生时不存半轮，关闭嵌套生成器并释放锁。
- **保存与网络确认不是一个事务**：保存后、result/end 送达前断开，服务端可能已保存；客户端提示“未能确认本轮是否保存”，不自动重发，也不承诺回滚成功轮次。无幂等键／历史查询 API，仍需后续完善。
- Flutter 连接／响应头等待 30 秒、行读取空闲 195 秒、请求总计 240 秒；页面销毁关闭该页请求，不影响其他页面。超时、错误、缺少终态均结束等待状态；完成／错误回调至多一个。

### 兼容范围

- 旧 Flutter 的 `data:` 行消费者仍可读 delta 的 `reply`，在 result 或 error 的 `done=true` 停止；status/end 不含 reply，不会追加文字。前提是旧端已有 error 优先判断（Phase 1B 已加入）。
- 新 Flutter 支持无 `type` 的旧格式；旧端成功 `done=true` 即结束，不要求新 end。该模式不能获得 v1 的顺序和完整性保证。
- v1 客户端按空行组帧，支持 CRLF、多行 data、注释和 UTF-8 分块；检查版本、序号、会话、最终文本一致性。只有 result＋成功 end 才触发 onDone。
- 外部 Python 直接消费 `ChatService.chat_stream` 时，服务错误现在转为 error/end，而不是抛出 ModelError；API HTTP 路径不变。调用方提前退出应显式关闭异步生成器。

## 尚未解决

报告等旧 API 的宽泛字典输入还没有全面收紧；例如空 `best_choice` 会触发旧逻辑错误，本轮未将其改造为新报告流程。
`action_data` 仍是兼容字典，不是有商品证据的报告 Schema；应随检索／报告阶段替换，不把通过语法校验等同于推荐有据。
未实现会话账号授权、跨进程锁或会话管理 API；本地文件存储请使用单进程，勿当作生产级多用户隔离。
