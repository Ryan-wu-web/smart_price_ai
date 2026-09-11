# 当前架构：Phase 1A–1C

更新：2026-09-11。本文区分当前可验证实现和后续目标，不将目标架构写成现状。

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
                     └─ 本地 Mock 商品对比／模拟趋势
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

## 验证边界与后续顺序

1. **Phase 1A 已完成离线验证**：缓存、识别 Schema、传输生命周期与既有接口兼容检查。
2. **Phase 1B 已完成离线验证**：会话持久化、摘要与识别上下文。
3. **Phase 1C 已完成离线及本地 HTTP 模型桩验证**：SSE 协议、增量解码、错误／取消与 Flutter 消费。现有 Phase 1 工程检查 32/32 通过，不等于所有产品验收要求均已满足。
4. **Phase 2–5 尚未完成**：商品知识 RAG、需求结构化、硬过滤／软排序、单 Agent 状态机、长期偏好、80 条产品评测；旧报告等业务专用 Schema 也随相应模块收紧。

离线模型桩检查不证明真实视觉识别质量、购物推荐质量或真实模型首字延迟；部署、真实模型及真机尚未验证。
具体命令、结果与回退范围见 [1A 记录](modules/01a-recognition-foundation.md)、[1B 记录](modules/01b-conversation-context.md)和 [1C 记录](modules/01c-streaming-protocol.md)。
