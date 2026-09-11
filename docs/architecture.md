# 当前架构：Phase 1A–1C、Phase 2A–2B 与 Phase 3A–3B

更新（本地验证日期）：2026-09-12。本文区分当前可验证实现和后续目标，不将目标架构写成现状。

## 当前调用链

```text
Flutter 原有页面 → FastAPI 路由
                     ├─ lifespan：创建／关闭每进程 HTTP 连接池
                     ├─ 依赖：LLMClient / VLMClient 借用共享连接池
                     ├─ 识别：图片校验／方向修正／压缩
                     │        → 模式、模型和版本隔离的精确缓存
                     │        → 模型请求 → 有限 JSON 修复 → Pydantic
                     │        → 单目标或多目标响应 → 原子写缓存
                     ├─ chat：校验输入 → 会话锁 → 读取／校验历史与商品上下文
                     │        → 摘要 + 用户原文 + 最近历史 → 模型回复 Schema
                     │        → 原子保存完整历史与上下文 → JSON／SSE v1 五类事件
                     ├─ 原有 suggest/filter/report（借用同一池）
                     ├─ 本地 Mock 商品对比／模拟趋势（尚未迁移）
                     └─ knowledge 只读API → 已校验的固定样例快照 → 商品／证据
                          （暂未接入 Flutter、聊天和旧比价）
```

`BaseAPIClient` 负责传输、连接池工厂、安全错误分类及模型非流式 envelope 校验。
`LLMClient` 负责 JSON 围栏解析、Pydantic TypeAdapter 与有上限的结构修复。
`RecognitionService` 保留原识别流程；单目标输出失败可两阶段降级，多目标失败明确报错。
路由保持 API 路径、成功响应的 JSON 形状及主要 Flutter 调用兼容性。

缓存文件在 `backend/data/cache/recognition`（从 backend 启动时），key 由原始图片字节 SHA-256、任务模式、模型／端点、预处理参数和版本共同决定。
缓存内容包含版本、模式、时间戳与通过 Schema 校验的结果；旧缓存、过期缓存、坏 JSON／Schema 均视为未命中。
原子替换防止读到半写文件，写失败不影响当前识别；不自动清空旧缓存，也未实现总容量淘汰。
选择精确缓存是为了避免 dHash 碰撞；相似重拍不再承诺命中。同图并发请求还未做请求合并。

## 会话与识别上下文（Phase 1B）

`SessionStore` 保存版本 2 JSON：`version/messages/summary/summarized_count/current_product`。
`messages` 保留完整成功轮次；摘要不删除原文。旧消息数组先校验，下一次成功回复时才写成新格式。
坏文件或不支持的版本返回可理解的错误，不吞错、不清空，不覆盖旧文件。

- 会话 ID 在 API 和服务层校验，拒绝路径字符、Windows 设备名和已有符号链接。
- 同一事件循环内各服务实例共享按会话分组的锁，不同会话可并行。锁等待最多 30 秒；未占用的锁条目弱引用释放。
- 一轮从读历史到保存都在锁内。写同目录临时文件、flush/fsync 后原子替换；失败清理临时文件并明确报错。
- 模型回复失败或流取消不追加半轮记录。SSE 文本仍可能在最终校验前显示，但只有最终校验和保存成功才算完成。
- 超过 8 条未摘要历史时尝试 JSON 摘要，保留最近 6 条；早期用户原文仍进入 Prompt，防止摘要遗漏硬条件。失败保留原历史，成功摘要跨请求复用。
- 会话文件最多 2 MB，Schema 最多 500 条消息，接近上限时停止追加；Prompt 最多 48,000 字符，超限明确要求新建会话，不静默截断。这是资源保护，不是模型 token 长度保证。

Flutter 识别详情（包括人工修正）经 `initialRecognition` 传入聊天，不要求 ID 或价格。
后端只保留经过 `ChatProduct` 校验的客户端上下文；未传新商品时沿用已保存商品，显式传新商品时替换。
模型返回的 `current_product` 不会覆盖商品字段。该上下文是识别／客户端提供的信息，**还不是商品知识库证据**。

本地会话只适用于**单后端进程、单实例**。进程内锁不是分布式锁，不能让多个 worker/容器共享这些文件写入。
会话 ID 不是身份验证；当前无账号鉴权、会话归属校验或文件加密，不应直接开放到公网处理私人对话。
Redis、PostgreSQL／SQLAlchemy 尚未接入主路径，本地启动不依赖它们；短期状态与长期偏好的完整设计留待 Phase 4。
本轮未新增包、Agent 框架、向量数据库或下载 Embedding 模型。

## 流式边界（Phase 1C）

```text
模型 SSE 完整帧 → LLMClient 校验 delta 与 stop/[DONE]
               → ReplyDecoder 只提取顶层 reply 的完整字符
               → status / delta（临时显示，不保存）
               → 完整 JSON＋唯一键＋ChatModelResult 校验
               → 原子保存 → result → end(success=true)
失败           → error → end(success=false)
取消           → 关闭生成器／上游连接，释放会话锁（不能保证再发送事件）
```

`core/streaming.py` 定义事件 Schema 与小型增量字符串解码器，不引入 Agent 框架或新增依赖。
模型分块、JSON 字符和应用 SSE 帧是不同边界：不能用正则等待结束引号，也不能把任意网络行当完整事件。
Flutter 的 `chat_stream_decoder.dart` 负责组帧和状态校验；`api_service.dart` 负责传输时限、取消与至多一次完成／错误回调。
`chat_screen.dart` 复用原页面，显示 context/model/validation/save 的真实状态；不是伪造检索工作流。

连接池继续由应用生命周期管理；请求取消只关闭相应响应，不关闭其他请求共用的池。
整轮处理预算与 HTTP 空闲超时分开配置，移除人为 15ms 逐字延迟；本地桩的分块到达验证不是模型首字性能评测。
流式失败不自动重放，暂不提供恢复游标或幂等请求。保存后的传输失败可能导致客户端无法确认；不承诺将文件提交与网络送达合为一个事务。

## 固定样例知识库（Phase 2A）

`models/knowledge.py` 定义商品事实、参数、价格区间、来源、目录及响应 Schema。
`catalog/sample-products.v1.json` 是随代码分发的单一数据源，不放入被忽略的 `data/` 运行目录。
它包含18条虚构商品记录与一个明确标为 `local_synthetic` 的来源；不是从已有随机 Mock 或真实电商导入。

```text
lifespan → ProductCatalog 读取最多2MB原始字节
         → 拒绝重复JSON键／无效编码／非有限数
         → Pydantic校验字段、ID唯一性、来源引用、价格区间
         → 每worker只读内存快照 + 原始文件SHA-256（样例JSON由.gitattributes固定LF）
GET knowledge/products → 精确品类／品牌过滤 → product_id稳定排序 → 分页
GET knowledge/products/{id} → 商品副本 + 快照身份
GET knowledge/evidence/{id} → 同一商品事实 + 来源 + /products/N定位 + 快照身份
```

2A的 ID 字典只是查找映射；2B在其上独立构建下述字段混合索引，浏览接口不使用检索排序。
证据从同一份校验后的商品字段生成，避免两份描述漂移；返回深拷贝，防止调用者污染快照。
参数含 `value/unit/label`，未知值是 `null`；耳机单耳与头戴整机重量使用不同参数键，不能直接混排比较。
价格为合成 `min/max/CNY` 区间，不是实时价格或历史序列。

知识文件缺失、过大或不合法时，记录安全错误类型并将 knowledge API 标记为503；不调用模型补齐、不回退旧随机Mock。
健康接口仍表示进程存活，而非所有子模块就绪。文件变动需重启加载；多worker需使用相同版本文件，响应SHA可用于核对。
现有 Dockerfile 的 `COPY app/ ./app/` 已覆盖该文件；没有新增依赖、写接口、配置或数据库迁移。
旧比价、趋势、报告和聊天尚未消费这个知识库，不能将它们的结论称为有据推荐。

## 样例字段混合检索（Phase 2B）

```text
lifespan → ProductCatalog只读快照
         → ProductRetriever：字段／列表项切片＋商品/证据/来源/字段定位Metadata
         → BM25倒排索引＋字符TF-IDF稀疏向量倒排索引（无外部依赖）
POST knowledge/search → SearchRequest校验
         → category/brand精确前置过滤
         → 片段级关键词／向量打分 → 各通道按商品取最大片段分 → 各取前40
         → 商品级RRF去重融合 → 证据选择＋词项覆盖率／字段类型确定性重排
         → SearchResponse：片段原值＋来源/快照定位＋分项分数＋相关性原因
```

`core/retrieval_config.py`集中定义规则和权重；`models/retrieval.py`定义请求／响应Schema；`services/retrieval.py`负责分词、索引、召回与重排。
字段切片没有重叠窗口：标量按字段、参数按键、数组按条切分，避免把同一商品的相反事实合并成正向解释。
返回片段仍可能是负向事实，必须保留role及原值；检索不等于购物约束判断。
数值原样保存，纯数字向量词项只完整匹配，计量单位／比较运算不在此阶段解析。

索引携带目录版本／SHA，指纹还包含检索参数、字段规则和算法版本。没有复制独立商品事实库或写入用户会话。
不读取可变工作目录；通过2A的`iter_products()`副本遍历完整快照，避免默认分页截断超过100条商品的索引。
过滤先于每路候选截断；语料IDF使用整个目录统计，不随筛选重新训练。按商品聚合后再融合，避免重复片段虚增商品票数。

向量实现是字符2–4元片段的TF-IDF＋余弦，不是预训练Embedding；纯语义改写、单汉字、否定表达或库外商品仍可能漏召回／误召回。
重排是可重建分数的确定性检索Rerank，不是学习式Cross-Encoder，也不替代预算／功能硬过滤或用户软偏好评分。
索引异常只影响搜索；日志记录模式、计数、指纹和异常类型，不记录查询文本／商品全文／原始异常。
没有新依赖、模型下载、数据库服务或Docker COPY变更。旧聊天、比价、报告及Flutter尚未消费此索引，不能宣称端到端有据推荐。

## 结构化短期需求（Phase 3A）

```text
POST requirements/parse（独立于旧聊天）
  → RequirementParseRequest：完整previous状态＋消息／显式编辑，严格Schema
  → 脱离输入的状态副本，校验撤销／待确认ID及用户确认标记
  → 按分句完整匹配规则；不支持的表达保留pending，不调用模型
  → 追加结构化硬条件／软偏好；保留来源、轮次和已撤销记录
  → 硬条件冲突检查＋基础购物信息完整度判断
  → RequirementParseResponse：state＋有效条件视图＋问题／冲突／警告
```

条件以field/key/operator/value/unit/strength表达，预算与参数不共用无单位数字；布尔功能保持JSON布尔，经过真实HTTP往返验证。
同槽位硬条件按交集并存，只有用户显式确认撤销才解除旧约束；模糊、否定和更正语句不被模型擅自解释为放宽。
解析器不读取摘要、识别结果、数据库或本地session文件，避免本阶段改变Phase 1B会话格式。客户端携带state只是工作输入，不是可信持久化偏好或身份记录。
`source`仅记录本次明确规则命中或结构化用户提交，不能拿来证明跨会话稳定偏好。后续Agent需要在服务端管理状态、接入识别候选确认及长期偏好权限。
`ready`仅检查基础购物槽位完整性；不同意图的完整度策略、候选存在性和工具执行许可仍属于后续工作流。
容量和词表集中配置，无新增依赖、环境变量、模型下载、Docker服务或数据迁移。
Phase 3B已修复原有知识HTTP层bool→float类型问题，并验证列表、详情、证据及推荐中的严格布尔／null／小数。RequirementParser.analyze现在可无副作用地评估state，不增加虚假轮次，原解析接口保持兼容。

## 完整事实推荐（Phase 3B）

```text
POST recommendations：requirements完整状态＋top_k
  → 只读需求评估：缺槽位／pending／冲突时返回问题；非推荐意图不执行
  → 硬品类精确圈定完整目录范围
  → 既有混合检索：相关片段、召回计数、原值证据
  → 用同品类完整快照补齐候选（不让搜索top-K造成假空结果）
  → evaluate_condition：逐条硬条件，matched / not_matched / unknown
  → 仅所有硬条件matched的商品进入score_preferences
  → 按field/key维度权重计算唯一软偏好匹配比例，记录分项与证据
  → score降序／ID升序，最后截取top_k，完整商品风险保留
  → Pydantic结果校验；无候选输出阻断统计和需确认的变更选项，不修改状态
```

`ProductRecommender`只依赖已有目录、索引和需求解析器；没有LLM排序、Embedding下载或新依赖。
`recommendation_config.py`集中版本、政策说明、权重与上限；旧知识Schema将bool放在数字前，保护严格HTTP类型。
索引故障／快照不一致明确降级为完整目录扫描；目录故障或过滤／评分／结果异常安全失败503。
日志记录retrieval、filter_rank、validate节点、状态及计数，不记录原始需求、偏好值或异常文本；这不是Phase 4的持久化Agent State。
当前以小型只读目录全扫描保障覆盖；检索仍为BM25＋字符TF-IDF，不是神经语义Embedding。
自由文本风险保留展示但不做语义推断，用途只验证明确精确声明；知识不足拒绝硬条件而非补造参数。
独立API不调用旧模型／数据库，不修改Flutter、chat、report、session格式；识别实体确认、状态编排和前端展示属于下一阶段。
无新环境变量、Redis／PostgreSQL接入或Docker配置要求；沿用README原启动命令。

## 验证边界与后续顺序

1. **Phase 1A 已完成离线验证**：缓存、识别 Schema、传输生命周期与既有接口兼容检查。
2. **Phase 1B 已完成离线验证**：会话持久化、摘要与识别上下文。
3. **Phase 1C 已完成离线及本地 HTTP 模型桩验证**：SSE 协议、增量解码、错误／取消与 Flutter 消费。现有 Phase 1 工程检查 32/32 通过，不等于所有产品验收要求均已满足。
4. **Phase 2A 已完成离线与本地 HTTP 验证**：严格商品知识 Schema、18条固定样例、Metadata查询、证据定位及坏文件隔离。
5. **Phase 2B 已完成离线与本地 HTTP 验证**：字段切片、BM25＋字符TF-IDF召回、前置Metadata过滤、商品级融合、确定性检索重排和原值证据。
6. **Phase 3A 已完成离线与本地 HTTP 验证**：严格需求Schema、保守规则分句解析、携带式增量状态、显式撤销／待确认、冲突及基础槽位判断；未接入聊天／Flutter。
7. **Phase 3B 已完成离线与本地 HTTP 验证**：知识布尔类型、完整事实过滤、加权软偏好排序、分项证据、无候选解释、明确索引降级；独立于旧聊天。
8. **Phase 4–5 尚未完成**：聊天／Flutter／报告接入、识别实体确认、单Agent状态机、长期偏好、80条产品评测；不是完整拍照到报告链路。

离线模型桩检查不证明真实视觉识别质量、购物推荐质量或真实模型首字延迟；部署、真实模型及真机尚未验证。
具体命令、结果与回退范围见 [1A 记录](modules/01a-recognition-foundation.md)、[1B 记录](modules/01b-conversation-context.md)、[1C 记录](modules/01c-streaming-protocol.md)、[2A 记录](modules/02a-product-knowledge.md) 、[2B 记录](modules/02b-hybrid-retrieval.md) 、[3A 记录](modules/03a-structured-requirements.md)和[3B记录](modules/03b-evidence-ranking.md)。

## Phase 4A：确定性购物工作流

新聊天输入 `shopping` → SessionStore单会话锁 → 显式意图／规则需求更新 → 完整度追问 → ProductRetriever混合召回 → ProductRecommender完整事实硬过滤与软评分 → 证据解释／同快照报告 → WorkflowState校验 → 消息及状态原子保存。

工作流运行在现有ChatService中，不引入Agent框架或新依赖；只读推荐计算移到线程，节点回调通过事件循环队列送到SSE。取消停止等待且不提交会话；已经开始的只读线程计算可能自行完成，不声称Python线程可强制取消。最终单帧大小有限制。状态只保存最新购物快照，旧文本消息仍保留；长期偏好尚未实现，也不会从识别或模型猜测自动保存。

Legacy新会话仍可调用原LLM路径，购物状态一旦建立后续保持购物路径。新工作流报告不调用旧report路由。Redis／PostgreSQL与旧Mock迁移仍待后续模块；本地SessionStore只允许单worker，GET会话不是生产鉴权边界。详见 `docs/modules/04a-shopping-workflow.md`。

## Flutter 购物链路（Phase 4B）

聊天页显式发送shopping并按本机最新revision更新；用户确认条件撤销后发送confirm_changes和expected_revision。GET会话恢复只读，失败不重发POST。报告直接呈现workflow.report，不调用旧report接口。客户端再次核验硬检查／商品证据归属／报告快照一致性，详情见modules/04b-flutter-shopping.md。

## 记忆边界（Phase 4C）

会话文件是当前需求／工作流的事实来源；SQLite长期偏好仅接受用户确认的结构化编辑。工作流只在确认指定偏好ID和版本时调用PreferenceStore读取，不自动保存模型推测；应用偏好仍通过原硬过滤、软排序。SQLite失败不切换事实来源，不依赖Redis/PostgreSQL存活。本地单worker，远端多用户适配尚未实现。设计取舍与验证见modules/04c-preferences-memory.md。

## 旧数据链路统一（Phase 4D，取代上文旧Mock待迁移说明）

旧compare → 应用生命周期内同一个ProductCatalog → 严格过滤 → 固定ID／样例区间投影；旧report → 按ID查同一个目录 → 带SHA和证据的知识摘要。删除随机MockDataSource、伪造历史生成器及不再调用的建议／趋势／报告Prompt。trend保持路径但返回明确无数据；suggest改为导航工具，不再让模型写渠道承诺。该路径不接电商、评分、销量、历史行情。
