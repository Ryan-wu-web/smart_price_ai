# Day 3：HTTP 通信 — 前后端的"电话线"

> 目标：理解客户端和服务端怎么通信，RESTful API 是什么，JSON 是什么，SSE 流式传输怎么工作。

---

## 1. 前后端怎么通信？

想象客户端和服务端是两栋楼，HTTP 就是它们之间的**电话线**。

```
客户端（Flutter）          HTTP 请求           服务端（FastAPI）
     |        ───────────────────────>        |
     |    POST /api/v1/recognize              |
     |    { "image": "base64..." }            |
     |        <───────────────────────        |
     |    { "name": "Air Force 1", ... }      |
```

**一次通信 = 请求 + 响应**：
- 客户端发**请求**：我要识别这张图片
- 服务端回**响应**：这是识别结果

---

## 2. HTTP 请求长什么样？

```http
POST /api/v1/recognize HTTP/1.1
Host: 10.23.198.80:8000
Content-Type: application/json

{
  "image": "base64EncodedImageString..."
}
```

**三部分**：
1. **请求行**：`POST`（方法）+ `/api/v1/recognize`（路径）
2. **请求头**：`Content-Type` 告诉服务端我发的是 JSON
3. **请求体**：真正要传的数据（图片的 base64）

---

## 3. RESTful API 是什么？

RESTful = 一种设计 API 的**风格/规范**。

**核心规则**：用 URL 表示资源，用 HTTP 方法表示操作。

| HTTP 方法 | 操作 | 例子 |
|-----------|------|------|
| GET | 获取数据 | `GET /api/v1/trend/Nike` 查价格走势 |
| POST | 提交数据 | `POST /api/v1/recognize` 上传图片识别 |
| PUT | 更新数据 | `PUT /api/v1/chat/123` 更新对话 |
| DELETE | 删除数据 | `DELETE /api/v1/history/123` 删除记录 |

**我们项目的 API 设计**：
```
POST /api/v1/recognize         → 单目标识别
POST /api/v1/recognize/multiple → 多目标识别
POST /api/v1/chat              → 普通聊天
POST /api/v1/chat/stream       → 流式聊天 ⭐
POST /api/v1/compare           → 跨平台比价
GET  /api/v1/trend/{name}      → 价格走势
POST /api/v1/report            → 生成决策报告
```

---

## 4. JSON 是什么？

JSON = **数据格式**，前后端都用它来传数据。

```json
{
  "name": "Air Force 1",
  "brand": "Nike",
  "price": 749,
  "tags": ["自营", "官方"]
}
```

**特点**：
- 纯文本，人和机器都能读
- 键值对结构（key: value）
- 支持字符串、数字、数组、布尔值

**为什么不用 XML？** JSON 更轻量、更易读、解析更快。

---

## 5. SSE 流式传输（重点 ⭐）

**问题**：普通 HTTP 是一次性返回全部结果。AI 聊天要逐字显示，怎么办？

**答案**：SSE（Server-Sent Events）

**普通 HTTP vs SSE**：

| | 普通 HTTP | SSE |
|--|-----------|-----|
| 连接 | 一次请求，一次响应 | 一次请求，多次推送 |
| 返回 | 等全部生成完再返回 | 生成一点就推送一点 |
| 体验 | 用户等待 10 秒，然后突然看到全部 | 用户立刻看到字一个一个出现 |

**SSE 数据格式**：
```
data: {"reply": "根"}

data: {"reply": "据"}

data: {"reply": "您"}

data: {"reply": "", "done": true, "action": "report"}
```

**项目中 SSE 怎么实现的？**
- 后端：FastAPI `StreamingResponse`，逐字 yield
- 前端：HTTP SSE 客户端，收到一个字符就更新页面

**答辩话术**：
> "为了消除 AI 等待焦虑，我们采用 SSE 流式传输。后端通过 FastAPI 的 StreamingResponse 逐字推送 AI 回复，前端实时接收并追加渲染，实现类似 ChatGPT 的打字机效果。"

---

## 6. 自检问题

1. HTTP 请求包含哪三部分？（请求行、请求头、请求体）
2. POST 和 GET 的区别？（POST 提交数据，GET 获取数据）
3. 为什么用 JSON 传数据？（轻量、易读、解析快）
4. SSE 和普通 HTTP 的区别？（SSE 一次连接多次推送）
5. 打字机效果怎么实现的？（后端逐字 yield，前端逐字追加）

**全部答对 → Day 3 通关 ✅**
