# API：当前实现与兼容边界

更新（本地验证日期）：2026-09-12，Phase 1A–1C、Phase 2A–2B 与 Phase 3A–3B。以运行时 `/openapi.json` 和 `/docs` 为接口 Schema 权威来源。
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

## 固定样例商品知识库（Phase 2A）

三个新增只读接口，不改变现有 API。不需要模型密钥或数据库。
这是**虚构样例知识查询**，不是实时电商、RAG召回或最终推荐；旧聊天／比价尚未使用它。

| 方法 | 路径 | 响应 Schema |
| --- | --- | --- |
| GET | `/api/v1/knowledge/products` | `ProductListResponse` |
| GET | `/api/v1/knowledge/products/{product_id}` | `ProductDetailResponse` |
| GET | `/api/v1/knowledge/evidence/{evidence_id}` | `EvidenceResponse` |

### 查询及返回约定

- `category`、`brand`：可选，1–80字符，不允许全空白；去除首尾空白后精确匹配，区分大小写，不做别名或模糊召回。
- `limit`：默认20，范围1–100；`offset`：默认0，非负整数。
- `product_id`／`evidence_id`：1–64字符，首字符小写字母或数字，其后允许小写字母、数字、`_`、`-`。
- 列表：`{catalog, total, limit, offset, products}`。`total` 是过滤后分页前总数；按 `product_id` 升序稳定分页，**不是推荐分数顺序**。
- 未匹配过滤条件或越过末页返回200与空数组；不会静默去掉品牌／品类条件。
- 详情：`{catalog, product}`；证据：`{catalog, evidence_id, product_id, source, locator, fields}`。

`catalog` 每次包含 `schema_version/dataset_id/revision/sha256/product_count/data_kind/notice`。
`sha256` 对源文件原始字节计算，样例JSON固定LF以避免跨平台换行漂移；版本与哈希用于标识证据快照，不是服务端签名、真实数据认证或HTTP缓存协商。

### 商品知识 Schema

| 字段 | 含义 |
| --- | --- |
| `product_id` | 固定样例商品 ID，如 `sample-shoe-01`，不映射旧 `mock-*` |
| `name/category/brand/model` | 非空虚构名称、品类、品牌与型号 |
| `parameters` | 参数键到 `{label, value, unit}` 的映射；标量value或null，unit可空 |
| `price_range` | `{min,max,currency:"CNY"}`；非负有限数且min≤max，均为样例设定 |
| `use_cases` | 适用场景 |
| `advantages/disadvantages` | 样例优点与缺点 |
| `exclusions` | 商品不适用情形，不是从用户推测的长期排斥条件 |
| `buying_advice` | 选购提醒，不保证真实体验 |
| `source_id/evidence_id` | 来源与证据ID，目录加载时检查引用和唯一性 |
| `data_kind` | 必须为 `sample` |

样例源 `kind` 必须为 `local_synthetic`，描述明确无电商或厂商来源。未知参数保留 `null`，不能解释为0、false或支持某功能。
参数键使用下划线标识；不同计量口径不应直接比较，例如 `earbud_weight_g` 是单耳重量，`device_weight_g` 是头戴耳机整机重量。
所有模型禁止额外字段，拒绝非有限数、数值字符串充当价格、重复ID、缺失来源和倒置价格区间。

### 证据追溯

例如 `/api/v1/knowledge/evidence/ev-shoe-01` 返回：

- `product_id = sample-shoe-01`；
- `source.source_id = src-local-synthetic-v1`，`source.kind = local_synthetic`；
- `locator = /products/0`，是 `backend/app/catalog/sample-products.v1.json` 中的 JSON Pointer；
- `fields` 包含该商品的所有 `ProductFacts` 字段，直接从校验后的快照生成，不由LLM补充；
- `catalog` 标识当前样例版本与文件SHA，并带有虚构数据声明。

来源＋数据集／revision＋SHA＋locator＋商品／证据ID应一起保存。仅凭证据ID不能跨版本证明事实没变。
证据只证明“样例文件中有这项设定”，**不能证明真实商品具备该参数**。
目前只有当前快照；历史快照需通过Git版本保留，不提供历史证据API或价格趋势。

### 错误与运行时

- 422：非法查询或ID格式；FastAPI标准输入校验响应。
- 404：合法ID不存在，`detail.code` 为 `PRODUCT_NOT_FOUND` 或 `EVIDENCE_NOT_FOUND`。
- 503：目录加载失败，`detail = {"code":"CATALOG_UNAVAILABLE","message":"样例商品库暂时不可用，请稍后重试。"}`。
- 文件加载上限2,000,000字节，最多5000条商品；当前只有18条，不代表已验证大规模知识库性能。
- 每worker启动读取一次；不热加载、不接受用户传入文件路径。修改数据需递增revision、校验并重启。
- 目录失败不阻止进程启动或其他接口工作，`/health` 仍可能返回200；不得将健康接口当知识库就绪检查。


## 样例知识混合检索（Phase 2B）

`POST /api/v1/knowledge/search` → `SearchResponse`。请求为JSON，不改动原三个GET接口。
此接口只检索样例字段，不调用模型、不执行预算／功能硬约束，不输出最终购买推荐。

```json
{"query":"雨天通勤","category":"运动鞋","top_k":5,"mode":"hybrid"}
```

| 输入 | 规则 |
| --- | --- |
| `query` | 必填字符串，去首尾空白后1–240字符，含字母或数字（含汉字）；拒绝空白和纯符号。NFKC归一化后最长480字符 |
| `category/brand` | 可选，null或1–80字符；去首尾空白后精确匹配，过滤先于通道候选截断，不隐式去除过滤条件 |
| `top_k` | 严格整数，默认5，1–10；不接受字符串或布尔值 |
| `mode` | `hybrid`（默认）、`keyword`、`vector`；后两者用于独立查询／通道对照，不触发模型 |

拒绝未知输入字段。query分析采用NFKC＋小写、汉字二元词项／ASCII词及型号；字符向量使用2–4元字符片段，纯数字按完整词项编码，避免局部数字误匹配。不是分词大模型或语义Embedding，单汉字查询可能没有词项匹配。

### 输出与证据

- `catalog`：沿用2A快照身份和样例声明；目录文件未修改。
- `index`：`algorithm`、`fingerprint`、`chunk_count`、`keyword_vocabulary`、`vector_vocabulary`、`vector_method="character_tfidf"`。指纹包含算法版本、参数、字段／角色规则及目录身份；不是签名或质量分数。
- `request`：通过校验的原请求（首尾空白已去除，不回显内部归一化词项替换后的查询）。
- `eligible_products`：精确品类／品牌过滤后数量。
- `recalled_products`：每路至多40个商品，经去重融合后、最终top_k截断前的数量。不是全库满足购物条件的商品数。
- `hits`：按相关性分数降序，平分按商品ID升序；每商品最多一条。
- `empty_reason`：成功有命中为null；`no_metadata_match`是过滤后无商品；`no_term_match`是没有通过词项／字符向量阈值的命中。空结果200，明确返回空数组，不放宽过滤、不生成替代商品。
- `warnings`：始终提示样例检索与条件判断、负向证据、字符向量的限制。

每条命中含 `product_id/evidence_id/name/category/brand/model`、`score`、`scores`、`matched_fields`、`match_reasons` 和最多5条 `evidence`（默认配置）。
`scores`记录最高BM25分数、最高字符余弦相似度、两路名次、融合分、词项覆盖率及字段类型分。分数反映资料相关性，**不是商品质量／推荐置信度**。

每条证据含：

- `chunk_id`（证据ID＋字段路径）、`product_id/evidence_id/source_id`；
- `field`，如`parameters/waterproof`或`use_cases/0`；
- `locator`，如`/products/3/parameters/waterproof`，对应当前目录原文件的JSON Pointer；
- `label`、`role`（`identity/fact/benefit/caveat/advice`）、校验后快照的字段`value`、确定性展示`text`；
- `matched_terms`、本片段的`keyword_score`及`vector_similarity`。

参数片段保留整个`{label,value,unit}`对象，列表按条切片；`false`和`null`不替换成“支持”。`text`由字段值格式化，不由LLM补齐。
角色是字段类型，不是完整的语义极性判断；即使role为fact，也必须读取value确认真假／未知。
来源详情可用原`GET /api/v1/knowledge/evidence/{evidence_id}`查询；消费端应核对catalog SHA一致，保留完整快照身份。证据只证明样例数据有该设定。

### 融合与重排

完整公式及默认参数见 [2B模块文档](modules/02b-hybrid-retrieval.md)。BM25和字符向量都在字段片段上打分，先按商品取该通道最大片段分，再分别截断候选。
商品级RRF避免同一商品因多片段重复命中获得额外投票；确定性重排使用融合分、返回证据的查询词项覆盖率及字段类型分。
这是检索Rerank，**不是Phase 3的硬约束过滤与软偏好排序**；不使用Cross-Encoder，也不声称学习排序或语义模型能力。

### 错误与运行边界

- 422：输入不符合Schema。
- 503：索引不可用／检索内部失败，`detail={"code":"RETRIEVAL_UNAVAILABLE","message":"样例商品检索暂时不可用，请稍后重试。"}`，不返回堆栈或内部异常文本。
- 每worker初始化一次；最多20,000片段、每路200,000词项，超过限制时拒绝建立索引而非只索引前一部分。
- 索引失败不阻断已有目录／识别／对话；目录失败时搜索也503。`/health`不是索引就绪检查。
- 无查询缓存、热更新或向量持久化；重启重建。未接入聊天、Flutter和报告，也不自动存入用户偏好。


## 结构化需求与增量编辑（Phase 3A）

`POST /api/v1/requirements/parse` 是新增的独立JSON接口；不替换 `/filter` 或 `/chat`，也不发送SSE。
解析器 `requirements-rules-v1` 没有模型／检索／数据库依赖，无外部网络、重试、Prompt或工具执行。
输入、结构化编辑、携带状态和最终输出均经Pydantic校验，禁止额外字段、非有限数值及布尔冒充金额。

### 输入与字段定义

```json
{"message":"推荐耳机，预算不超过500元，必须主动降噪，偏好品牌样例声屿，用于通勤"}
```

| 请求字段 | 含义 |
| --- | --- |
| `message` | 用户当前表达，最多4000字符；可省略以进行纯结构化编辑 |
| `previous` | 上轮返回的完整 `state`；省略表示新需求，不读取会话或磁盘 |
| `additions` | 最多32条显式结构化条件，见下表；调用端只能把用户明确提交的选择放入这里 |
| `intent` | 显式设置 `recommend/compare/explain/report/unknown`，优先于本轮规则识别结果 |
| `remove_condition_ids` | 撤销旧的有效条件ID；不物理抹除其记录 |
| `resolve_pending_ids` | 显式确认已处理的待补充项ID；只标记处理，不自动生成条件 |
| `confirm_changes` | 默认false；撤销或处理待补充项时必须true，不能由调用端静默代为确认 |

至少提供非空消息或一项编辑。`previous` 是客户端提交的短期工作状态，不是服务端认证的用户档案；来源记录只用于工程追溯，不作为身份、授权或长期偏好证明。
调用方必须保留整个state，不能只传硬条件；本接口不提供跨客户端并发版本控制，revision仅标记携带状态的轮次。

统一条件对象字段：

| 字段 | 允许值／含义 |
| --- | --- |
| `field` | `budget/category/brand/use_case/feature/parameter` |
| `operator` | `eq/ne/min/max`；min、max均含边界 |
| `value` | 字符串、布尔或有限非负数值；不自动把字符串数字转换成金额 |
| `strength` | `hard` 硬约束或 `soft` 软偏好；不包含排序分数 |
| `key` | feature/parameter必填，其余字段必须为空 |
| `unit` | 预算必须 `CNY`；数值参数必须规范单位，其余为空 |

- 预算仅支持min/max，数值范围0–100,000,000；默认规则视为硬上限／下限。
- 品类是硬eq/ne；品牌、用途及文本参数支持eq/ne，ne必须是硬排斥。
- 功能键：`waterproof/anc/multipoint/low_latency_mode`，只接受布尔eq，不把null当false。
- 数值参数：`weight_g/earbud_weight_g/device_weight_g` 单位g，`battery_hours` 单位h，`capacity_l` 单位L，`laptop_inches` 单位inch；支持eq/ne/min/max。
- 文本参数：`material/fit/color/form_factor/waterproof_rating`。未支持的参数键返回422，不伪造知识字段。未知品类／品牌可以通过显式编辑保留原值，但不证明样例库有对应商品。

### 输出与状态

返回 `parser_version/mode/state/status/confirmed_condition_ids/hard_constraints/soft_preferences/exclusions/conflicts/missing_information/questions/warnings`。

`state` 包含 `schema_version=1/revision/intent/intent_source/conditions/pending`：

- 条件有稳定ID和 `source={kind,turn,quote}`。rule来源保留用户分句原文；user_edit来源保留提交的结构化值。仅本接口直接识别或用户显式提交的有效条件列入confirmed，不读取或确认模型摘要中的推测。
- 撤销记录使用 `removed_turn`，已处理待补充项使用 `resolved_turn`；返回的硬／软条件视图只含当前有效项。
- 下一轮默认保留先前条件和待补充项；相同有效条件去重；不同条件并存，不默认用最后一条覆盖。
- 后一轮明确的意图覆盖当前意图；旧预算、品类等条件不会因此清除。
- 最多1000轮，条件记录和待补充记录各最多128条（含已撤销／已处理）；超限明确拒绝，不截断历史。

| status | 语义 |
| --- | --- |
| `ready` | 当前基础购物槽位（意图、硬品类、硬预算上限）齐备，无未处理分句及已检测冲突；不是候选存在／推荐成功，也不是不同Agent意图的最终执行许可 |
| `needs_clarification` | 缺失基础槽位或存在尚未理解的表达；返回问题 |
| `conflict` | 硬品类／标量参数不兼容、要求与排斥同值、数值区间为空，或已知样例品类不适用所要求的数值参数 |

所有有效硬条件应按交集执行；同槽位多个eq是同时必须满足，不表示“任选一个”。用途属于集合，可以同时要求通勤和旅行。
预算上限由500追加到800会保留两条，上限实际仍是500；返回叠加警告，不宣称放宽成功。
软偏好不触发硬冲突，不能覆盖硬条件。当前冲突检测不是求解所有自然语言逻辑，也不检测库中有没有候选；后续过滤必须读取完整商品事实，不能将未知视作满足。

### 增量更正示例

先将完整上一轮 `state` 放入 `previous`。以下是**编辑字段示例**，`c1-2` 应换成当前响应里的预算上限ID：

```json
{
  "remove_condition_ids": ["c1-2"],
  "confirm_changes": true,
  "additions": [{"field":"budget","operator":"max","value":800,"unit":"CNY","strength":"hard"}]
}
```

本示例省略了较长的previous；实际请求必须携带它，否则ID不存在时返回409。
自然语言“预算改成800元”不会自行删除500上限，而是保留为待确认信息；界面需要展示旧条件并由用户确认撤销。
处理模糊分句时，可以在同一请求新增准确条件、提交对应 `resolve_pending_ids` 和 `confirm_changes=true`；仅再说一条准确条件不会暗中清除未解决的分句。
所有编辑先校验再作用于脱离输入的副本，失败不会修改调用方原状态；无服务端写入。

### 当前规则语法和回退

每个分句必须整体匹配，推荐以逗号／分号分隔：

| 示例 | 结果 |
| --- | --- |
| `推荐耳机`、`我想买运动鞋`、`对比双肩包`、`解释耳机`、`生成报告` | 意图；支持的品类为运动鞋、耳机、双肩包 |
| `预算不超过500元`、`预算至少300元`、`预算300到500元`、`500元以内`、`预算1.5千元` | 硬预算；范围保留原顺序，不倒置修正 |
| `最好500元以内` | 软预算偏好，仍缺硬上限 |
| `偏好品牌样例声屿`、`只要品牌样例声屿`、`不要品牌样例听岚` | 分别为软品牌、硬品牌、硬排斥 |
| `必须主动降噪`、`最好防水`、`不要主动降噪` | 布尔功能的硬true、软true、硬false |
| `用于通勤`、`必须用于旅行`、`不要用于越野跑` | 软用途、硬用途、硬排斥用途 |
| `必须续航至少10小时`、`必须空包重量不超过0.8kg` | 参数硬条件及规范单位转换 |
| `必须单耳重量不超过6克`、`必须整机重量不超过250克` | 不同重量基准，不能混用 |
| `偏好颜色黑色`、`必须材质网布` | 文本参数软／硬条件 |

`最好/优先/偏好/希望/尽量`是软前缀，`必须/一定要/需要/只要/仅要`是硬前缀；一般品牌／功能／用途／文本参数未指定时默认软，明确数值界限默认硬。
规则和支持词表集中于 `app/core/requirements_config.py`；没有引入LLM实体理解。
不支持的复合表达、双重否定、“不要求防水”“预算左右”“预算取消”等保留原句并追问。
“1到2千元”不猜测省略单位，“1,000元”不拆成1元；请明确写成“预算1000到2000元”或“预算1000元”。
“跑鞋”不会直接放宽成所有运动鞋，“背包”不会擅自限定为双肩包，“降噪”不会冒充已确认的主动降噪。
超过500字的单分句或记录容量超限返回409，请拆分或开启新需求；不会静默裁剪。

- Schema或缺少显式确认：422。
- 不存在／已撤销的编辑ID：409，`REQUIREMENT_EDIT_INVALID`。
- 轮次、记录或单句长度超限：409，`REQUIREMENT_LIMIT`。
- 表达不支持／条件冲突：200及明确业务status，不转成空需求或错误推荐。

**边界**：需求解析接口本身不执行推荐；其state已可显式交给Phase 3B过滤排序接口。未接入旧聊天／Flutter或识别上下文；没有会话落盘、长期偏好、模型辅助解析或模型超时场景。本模块不调用模型，无需通过“模型兜底成功”来解释规则成功。
**已修复的知识类型问题（Phase 3B）**：旧知识详情响应曾将false序列化成0.0。现在商品列表、详情、证据与推荐均保留布尔类型，分数和价格仍为数字，null仍为未知；小数不会截断。旧客户端不应继续把0/1当作布尔事实。


## 有据过滤与偏好排序（Phase 3B）

`POST /api/v1/recommendations`，JSON响应，独立于旧`filter/chat/report`，不产生SSE，也不调用模型。

请求：`{"requirements": <需求解析接口返回的完整state>, "top_k": 5}`。
`requirements`使用Phase 3A的严格Schema；`top_k`是1–10的整数，默认5。不接受`relax`等自动放宽参数。
不增加revision、不修改原状态、不读取旧聊天、不落盘。`intent=compare/explain/report`不会伪装成已完成对比／报告。

### 响应与状态

| 字段 | 含义 |
| --- | --- |
| `algorithm_version` | `facts-ranking-v1` |
| `status` | `ready/needs_clarification/conflict/unsupported_intent/no_candidates` |
| `assessment` | 只读复用需求完整性和冲突判断，含原state及问题；其中ready不等于推荐成功 |
| `catalog` | 数据集ID、revision、SHA-256、样例声明 |
| `policies/weights` | 本轮使用的规则和软偏好权重 |
| `retrieval_status/retrieval` | `skipped/ok/empty/unavailable`及可用时的完整混合检索响应；不作为资格或偏好得分 |
| `scoped_products` | 硬品类精确匹配的完整目录商品数 |
| `supplemented_products` | 上述完整目录中未出现在检索返回hits里的商品数，不等于底层召回遗漏数 |
| `eligible_products` | 完成全部硬过滤后的总数，先排序再按top_k截取 |
| `recommendations` | rank、完整product、score、components、hard_checks、soft_checks、reasons以及满足／未满足／未知的条件ID |
| `rejected_total/rejected` | 淘汰总数及按商品ID最多10条淘汰详情（只列阻断条件）；计数和诊断仍基于全范围 |
| `constraint_impacts` | 每条硬条件不满足／未知的商品数，以及仅移除该项后通过其余硬条件的数量；各项阻断数可能重叠 |
| `relaxation_options` | 无候选时的可审视条件ID及上述单项移除计数，`requires_confirmation=true`，仅说明、绝不执行 |
| `empty_reason/questions/warnings` | `no_category_match/hard_constraints_not_met`；未执行或成功时empty_reason为空；普通用户提示与局限 |

每个条件检查是`matched/not_matched/unknown`，关联condition_id、解释、一个或多个事实引用。
引用含product_id/evidence_id/source_id/field/locator/value：locator是哈希目录内的JSON Pointer，value保持原字段值。
参数缺失时引用真实存在的整个`parameters`对象，不虚构不存在参数的路径。商品完整`disadvantages/exclusions/buying_advice`始终返回，不冒充已完成自由文本风险理解。

### 硬规则与软评分

- 先阻断缺槽位、pending、已知冲突；仅推荐意图执行。hard品类严格匹配，品牌不作为预截断条件，因此仍可给出品牌不满足原因。
- 混合检索查询由品类、正向品牌／用途、参数键构成，最多240字符；超过时明确告警。**所有条件仍完整过滤／评分**。
- 候选补齐同品类整个快照，即使检索仅返回前1条或0条也不据此判定候选为空。此完整扫描适合当前18条样例，不是大规模搜索性能承诺。
- 预算上限：`price_range.max <= 上限`；下限：`price_range.min >= 下限`。不能用最低价格冒充整个价格区间符合预算。
- 布尔必须是真正bool；数字不可使用bool，单位严格相同，单耳／整机／单只／空包重量不混用；null、缺字段、类型或单位错误为unknown。
- 文本／品牌／品类区分大小写，精确比较，不做子串或隐式同义词扩展。
- 用途在完整`use_cases`中精确出现才是支持，在完整`exclusions`中精确出现才是明确排斥；两者都没有或同时出现为unknown。不把未声明用途当作不支持；没有自由文本否定推理。
- 每个硬条件都必须matched；所有硬条件取交集。软偏好不能让被淘汰商品重回排序。
- 软维度是`field/key`；预算2、品牌1、用途2、每个功能键2、每个参数键2。一个维度内完全相同偏好去重，不同值／运算符按比例匹配。
- `satisfaction = 满足的唯一偏好数 / 该维度唯一偏好数`，未知和不满足均计0。
- `contribution = 100 × weight × satisfaction / 有效软维度总权重`；score是各贡献之和，四舍五入到6位。components同时返回条件ID、唯一偏好数、满足数、未知数、权重和贡献。
- 排序按score降序、product_id升序；无软偏好时全部0分，**不假设便宜优先，也不代表质量差**。检索相关性不加到偏好分中。

例如硬预算1200元耳机、软品牌“样例声途”（权重1）和软主动降噪（权重2）：`sample-audio-04`得100；`sample-audio-01/02`得66.666667，二者按ID并列顺序；这只是固定样例工程结果。

### 无候选、确认与错误

`no_candidates`不返回推荐或修改后的需求。单项移除计数只在当前品类内、按剩余硬条件计算，不保证移除后基础槽位仍齐备；例如删除唯一预算后仍须补充预算上限。
计数为0说明仅改这一项不够；可以审视多项条件或补充可靠知识，不能据此承诺候选。
请调用需求接口传previous、remove_condition_ids、必要的additions以及confirm_changes=true，再将返回state提交推荐；只追加更高预算不会撤销旧低预算。

| 情况 | HTTP／行为 |
| --- | --- |
| 请求Schema非法／额外放宽参数 | 422 |
| 缺信息／冲突／无候选／非推荐意图 | 200及明确业务status，没有候选推荐 |
| 知识库未加载 | 503，`CATALOG_UNAVAILABLE` |
| 索引为空 | 200，`retrieval_status=empty`、告警及同品类全目录事实扫描 |
| 索引未加载／查询异常／索引与目录SHA不一致 | 200，`retrieval_status=unavailable`、告警及相同硬规则的全目录扫描，不混用旧索引证据 |
| 过滤／评分工具异常、证据不一致或最终校验失败 | 503，`RECOMMENDATION_UNAVAILABLE`，友好提示、不输出异常原文 |

规则、权重、查询及详情上限集中于`app/core/recommendation_config.py`，不放进Prompt。无新依赖或环境变量。
旧对话中的随机Mock、静默放宽和无证据报告还没有改接本接口；本模块完成不代表原有业务链路已经满足全部升级目标。

## Phase 4A：购物会话接口

`POST /api/v1/chat` 与 `POST /api/v1/chat/stream` 保持原协议，增加 `shopping` 对象。未开启购物且没有购物历史的会话继续使用旧模型聊天；购物会话不调用LLM，因此离线无密钥仍可检索、追问和生成有据报告。

```json
{"message":"推荐耳机，预算500元，最好主动降噪","session_id":"local-shopping-1","shopping":{}}
```

后续发送同一 session_id 与 `message:"生成报告"` 或 `"解释推荐"`、`"对比候选"`。`action="none"` 用于防止旧客户端误调用旧报告页；新内容在 `action_data.workflow`，含 `requirements/assessment/status/recognized_product/recognition_confirmed/recommendation/report/missing_information/trace/errors/retries/notice`。报告 `choices` 与本轮候选完全一致，并记录 `requirements_revision/catalog_sha256`。仅本地虚构样例，不输出实时价格或历史趋势。

`shopping` 参数（严格 Schema，未知字段拒绝）：
- `top_k`：1–10，默认5。
- `expected_revision`：可选当前需求版本；不匹配409且不保存。
- `additions/intent/remove_condition_ids/resolve_pending_ids/confirm_changes`：与3A显式编辑语义相同；撤销／忽略还必须提供 `expected_revision`。
- `confirm_recognition`：默认false；true仅把明确确认的已识别品类作为条件，未支持品类422。品牌、价格和图像属性不自动进入约束。

前端确认控件可使用固定消息 `确认识别品类` 或 `应用已确认的条件调整`。这些只是与显式提交字段配合的UI命令，不能让普通未知句子绕过pending。

`GET /api/v1/chat/sessions/{session_id}`：返回工作流快照、current_product、摘要、最近20条消息。不存在404、损坏409；只适合本地单用户，不具有登录隔离。

SSE仍为v1，`status.node`新增 intent/requirements/completeness/clarification/retrieval/filtering/ranking/explanation/report（validation/save沿用）。确定性购物文字一次delta，不冒充模型token流；result之前的文本仍是临时显示，只有end.success=true后完成。无候选不放宽；目录／工具失败返回 `workflow.status=unavailable` 与安全错误，已确认需求保留。超时与保存失败发 error/end(false)；非流购物超时504。结果过大413且不保存。完整交付边界见 `docs/modules/04a-shopping-workflow.md`。

### Flutter 接入约定（4B）

购物页要求最终 `action_data.workflow`；缺失时提示后端版本不支持，不回退到无据模型推荐。会话恢复使用 `GET /api/v1/chat/sessions/{session_id}`。条件撤销和pending忽略需要确认与revision；报告发送“生成报告”，显示同一workflow内的report。历史快照不可修改。

## 长期偏好 API（Phase 4C）

- `GET /api/v1/preferences`：返回version、revision、items、storage=local_sqlite、notice。
- `POST /api/v1/preferences`：`expected_revision`＋严格布尔`confirmed:true`＋完整`items`；空数组为确认删除全部，修改或删除任意项都是完整替换。冲突409、无效422、存储不可用503。最多32项。
- item：id、condition（3A ConditionInput，仅budget/brand/use_case）、category（可空或耳机/运动鞋/双肩包）、confirmation_text。必须由用户明确提交。
- shopping增加preference_ids、preference_revision、confirm_preferences；选中的品类限定偏好仅能应用到已确认同品类，不覆盖已有硬条件。状态节点新增preferences，workflow携带本次／最近应用的偏好版本与ID用于追溯，不代表这些偏好永久仍激活。
- 本地单用户，无认证；示例、限制和恢复步骤见modules/04c-preferences-memory.md。
