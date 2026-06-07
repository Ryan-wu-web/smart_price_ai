# Day 4：FastAPI 后端 — 业务逻辑的大脑

> 目标：理解 FastAPI 的核心概念，以及项目中识别、聊天、比价服务是怎么实现的。

---

## 1. FastAPI 是什么？

FastAPI = **Python 的 Web 框架**，用来写后端 API。

**类比**：FastAPI 是一个餐厅的后厨管理系统，负责接收订单（HTTP 请求）、分配任务（调用服务）、出菜（返回响应）。

**为什么选它？**
- 异步原生（同时处理多个请求，不阻塞）
- 自动文档（自动生成 Swagger UI）
- 类型安全（Pydantic 自动校验参数）

---

## 2. 路由（Router）— 接收请求的入口

路由 = **菜单**。客户端发来的请求，根据 URL 路径分配到对应的处理函数。

```python
@router.post("/recognize")
async def recognize(request: RecognizeRequest):
    # 处理识别请求
    result = await recognition_service.recognize(request.image)
    return result
```

**项目中路由文件**：
- `routers/recognize.py`：识别相关接口
- `routers/chat.py`：聊天相关接口
- `routers/compare.py`：比价相关接口

---

## 3. Pydantic 模型 — 数据的"安检门"

Pydantic = **数据校验库**。确保客户端发来的数据格式正确。

**例子**：
```python
class RecognizeRequest(BaseModel):
    image: str  # 必须是字符串（base64）

class RecognizeResponse(BaseModel):
    name: str
    brand: str
    category: str
    color: str
```

**作用**：
- 客户端少传一个字段 → 自动报错（422 Unprocessable Entity）
- 类型不对 → 自动报错
- 不用手写校验代码

---

## 4. 异步编程（async/await）— 为什么快？

**同步 vs 异步**：

| | 同步 | 异步 |
|--|------|------|
| 比喻 | 只有一个收银员，逐个结账 | 有叫号系统，顾客先去坐着，好了叫号 |
| 特点 | 等一个请求处理完才能处理下一个 | 请求来了先挂着，CPU 去处理别的，好了再回来 |
| 适合 | 简单场景 | IO 密集型（网络请求、数据库查询） |

**项目中为什么用异步？**
- 调用 AI 模型要等 5-10 秒（网络请求）
- 如果用同步，这段时间服务端什么都干不了
- 用异步，等 AI 的时候可以去处理其他请求

```python
async def chat_stream(message):
    # 调用 AI（等 5 秒）
    async for chunk in llm_client.chat_stream(messages):
        yield chunk  # 生成一点就推给客户端
```

---

## 5. 服务层（Service）— 业务逻辑的核心

**分层设计**：

```
Router（接收请求）
  ↓
Service（处理业务）
  ↓
Client（调用外部 API）
  ↓
AI 模型 / 数据库
```

**项目中三个核心服务**：

| 服务 | 文件 | 职责 |
|------|------|------|
| 识别服务 | `services/recognition.py` | 图片压缩、dHash 缓存、调 VLM |
| 聊天服务 | `services/chat.py` | Session 管理、上下文组装、调 LLM |
| 比价服务 | `services/compare_service.py` | 多平台数据聚合、排序、筛选 |

**为什么分层？**
- Router 只负责 HTTP，不管业务
- Service 只负责业务，不管 HTTP
- 以后要换 AI 模型，只改 Client 层，Service 不用动

---

## 6. 依赖注入 — 怎么组装起来的？

FastAPI 的依赖注入 = **乐高插口**。需要什么东西，声明一下，FastAPI 自动给你。

```python
async def recognize(
    request: RecognizeRequest,  # FastAPI 自动把 JSON 转成对象
    service: RecognitionService = Depends(get_recognition_service)
):
    # 直接拿到校验好的请求对象和服务实例
    return await service.recognize(request.image)
```

**好处**：代码干净，测试方便（可以换 Mock 服务）。

---

## 7. 自检问题

1. FastAPI 为什么比 Flask 快？（异步原生，不阻塞）
2. Pydantic 是干嘛的？（数据校验，自动检查参数格式）
3. 为什么用 async/await？（IO 等待时不阻塞，能处理更多并发）
4. 后端分几层？（Router → Service → Client）
5. 依赖注入有什么好处？（代码解耦，测试方便）

**全部答对 → Day 4 通关 ✅**
