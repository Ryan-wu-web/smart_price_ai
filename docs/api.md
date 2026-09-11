# API：当前实现与兼容边界

更新：2026-09-11，Phase 1A。以运行时 `/openapi.json` 和 `/docs` 为接口 Schema 权威来源。
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
| POST | `/api/v1/chat` | 原有 JSON 对话 |
| POST | `/api/v1/chat/stream` | 原有 SSE，对话流协议仍待修复 |

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
这些模型错误同样在普通 chat/filter/report/suggest 请求中映射；**已发送响应头之后的 SSE 错误事件仍待 Phase 1 后续模块实现**。

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
| `MODEL_JSON_REPAIR_ATTEMPTS` | 1 | JSON 格式／Schema 修复次数，0–2 |

应用启动时创建共享 `httpx.AsyncClient`，通过请求依赖注入给 LLM/VLM，关闭应用时关闭池。
独立 Python 调用者若自行构造客户端，应使用 `async with LLMClient(...)` 或显式 `await client.aclose()`；借用外部 HTTP 客户端时，借用方不会关闭外部池。

## 尚未解决

会话 ID 路径限制、摘要保留、当前识别商品传递、SSE delta/node/result/error/end 及 Flutter 消费端仍待下一模块。
报告等旧 API 的宽泛字典输入还没有全面收紧；例如空 `best_choice` 会触发旧逻辑错误，本轮未将其改造为新报告流程。
