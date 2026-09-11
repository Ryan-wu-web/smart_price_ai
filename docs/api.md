# API：当前实现与兼容边界

更新：2026-09-11，Phase 1A + 1B。以运行时 `/openapi.json` 和 `/docs` 为接口 Schema 权威来源。
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
| POST | `/api/v1/chat/stream` | 兼容原有 SSE，统一事件协议仍待 Phase 1C |

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
这些模型错误同样在普通 chat/filter/report/suggest 请求中映射；已发送响应头后的已知会话／模型错误通过兼容终态 `done=true,error=中文提示` 返回；统一 error/end 协议仍待 Phase 1C。

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

在发出 SSE 响应头之前可以发现的坏历史返回 HTTP 409/413/503。
响应头之后的已知失败示例：

```json
{"done":true,"error":"回复未能保存，请稍后重试；原历史未修改。","reply":"","action":"none","action_data":{}}
```

客户端必须先判断 `error`，不能将该终态视为成功回复。新 Flutter 端已处理，并关闭该次流的 HTTP 客户端。
普通 POST 超时取消自动重试，避免服务端其实已保存但客户端再次发送；尚未实现请求幂等键，手动重试仍可能重复。

## 尚未解决

SSE 的真正 JSON 字符增量解析、node/result/error/end、统一取消与总时限仍待 Phase 1C；保留旧流解析和逐字延迟，不声称首字性能已优化。
报告等旧 API 的宽泛字典输入还没有全面收紧；例如空 `best_choice` 会触发旧逻辑错误，本轮未将其改造为新报告流程。
未实现会话账号授权、跨进程锁或会话管理 API；本地文件存储请使用单进程，勿当作生产级多用户隔离。
