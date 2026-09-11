# 当前架构：Phase 1A

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
                     ├─ 原有 chat/suggest/filter/report（借用同一池）
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

会话仍使用旧 JSON 文件逻辑；Redis、PostgreSQL／SQLAlchemy 尚未接入主路径，本地启动不依赖它们。
本轮未新增包、Agent 框架、向量数据库或下载 Embedding 模型。

## 验证边界与后续顺序

1. **Phase 1A 已完成离线验证**：缓存、识别 Schema、传输生命周期与既有接口兼容检查。
2. **下一步 Phase 1B**：会话 ID 安全、摘要可靠性、识别商品上下文；之后完成 SSE 和 Flutter。
3. **Phase 2–5 尚未完成**：商品知识 RAG、需求结构化、硬过滤／软排序、单 Agent 状态机、长期偏好、80 条产品评测。

离线模型桩检查不证明真实视觉识别质量、购物推荐质量或首字延迟；部署、真实模型及真机尚未验证。
具体命令、结果与回退范围见 [模块交付记录](modules/01a-recognition-foundation.md)。
