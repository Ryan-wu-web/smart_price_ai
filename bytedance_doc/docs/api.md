<div align="center">

# 📡 Smart Price — API 说明文档

<p align="center">
  <strong>RESTful API 接口定义 · 请求/响应格式 · 错误码</strong>
</p>

</div>

---

## 概述

Smart Price 后端基于 **FastAPI** 构建，提供 RESTful API 接口。服务启动后可通过 `http://<host>:8000/docs` 访问交互式 Swagger UI 文档。

| 项目 | 说明 |
|------|------|
| **Base URL** | `http://<host>:8000/api/v1` |
| **Content-Type** | `application/json` |
| **认证方式** | 无需认证（Demo 阶段）|
| **完整 OpenAPI 规范** | [`openapi.json`](openapi.json) |

---

## 核心接口

### 1. 商品识别（单目标）

```http
POST /api/v1/recognize
```

上传商品图片，返回识别结果。

**请求体**：

```json
{
  "image": "base64_encoded_image_string"
}
```

**响应体**：

```json
{
  "name": "Air Force 1",
  "brand": "Nike",
  "category": "运动鞋",
  "color": "白色",
  "style": "低帮",
  "confidence": 0.95
}
```

**说明**：
- 服务端先计算 dHash 感知哈希，查询缓存：命中则直接返回，未命中则调用 Doubao-VLM
- 图片会被压缩至 600px 宽、JPEG 质量 75%，减少传输体积

---

### 2. 多目标识别

```http
POST /api/v1/recognize/multiple
```

识别图片中的多个商品，返回每个商品的属性和位置。

**请求体**：

```json
{
  "image": "base64_encoded_image_string"
}
```

**响应体**：

```json
{
  "objects": [
    {
      "name": "怡宝矿泉水",
      "brand": "怡宝",
      "category": "饮料",
      "color": "透明",
      "center": { "x": 0.35, "y": 0.42 }
    },
    {
      "name": "资生堂红腰子",
      "brand": "资生堂",
      "category": "护肤品",
      "color": "红色",
      "center": { "x": 0.68, "y": 0.55 }
    }
  ]
}
```

**说明**：
- `center.x` 和 `center.y` 为归一化坐标（0-1），前端转为屏幕坐标后渲染气泡标签
- 当图片中只有一个商品时，返回 `single_result` 直接跳转单品页

---

### 3. AI 导购对话（普通）

```http
POST /api/v1/chat
```

发送消息，获取 AI 回复（阻塞式）。

**请求体**：

```json
{
  "message": "帮我选一双运动鞋",
  "session_id": "abc123",
  "current_product": {
    "name": "Air Force 1",
    "brand": "Nike"
  }
}
```

**响应体**：

```json
{
  "reply": "根据您的需求，我推荐以下几款运动鞋...",
  "action": "compare",
  "action_data": {
    "products": ["Nike Air Force 1", "Nike Dunk Low"]
  },
  "session_id": "abc123"
}
```

---

### 4. AI 导购对话（SSE 流式）⭐

```http
POST /api/v1/chat/stream
```

发送消息，以 SSE 流式方式获取 AI 回复，实现逐字显示效果。

**请求体**：同 `/chat`

**响应格式**：`text/event-stream`

```
data: {"reply": "根", "session_id": "abc123"}

data: {"reply": "据", "session_id": "abc123"}

data: {"reply": "您", "session_id": "abc123"}

...

data: {"reply": "", "done": true, "action": "compare", "action_data": {...}, "session_id": "abc123"}
```

**说明**：
- 每个 `data:` 事件包含一个字符的 `reply`
- 最后一条事件设置 `done: true`，并携带完整的 `action` 和 `action_data`
- 服务端将 LLM 返回的文本拆分为单字符，以 15ms 间隔逐个发送

---

### 5. 跨平台比价

```http
POST /api/v1/compare
```

根据识别结果查询多平台同款商品价格。

**请求体**：

```json
{
  "name": "Air Force 1",
  "brand": "Nike",
  "category": "运动鞋"
}
```

**响应体**：

```json
{
  "products": [
    {
      "name": "Nike Air Force 1 '07",
      "price": 749,
      "platform": "京东",
      "tags": ["自营", "官方"],
      "rating": 4.8
    },
    {
      "name": "Nike Air Force 1 '07",
      "price": 699,
      "platform": "天猫",
      "tags": ["旗舰店"],
      "rating": 4.7
    }
  ]
}
```

**查询参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `sort_by` | string | 排序方式：`price`（价格）/ `rating`（好评率）/ `sales`（销量）|
| `filter_mode` | string | 筛选模式：`official`（官方旗舰店）/ `similar`（相似推荐）|

---

### 6. 价格走势

```http
GET /api/v1/trend/{product_name}
```

获取商品历史价格走势数据。

**响应体**：

```json
{
  "product_name": "Nike Air Force 1",
  "trend_data": [
    { "date": "2025-01", "price": 799 },
    { "date": "2025-02", "price": 749 },
    { "date": "2025-03", "price": 699 },
    { "date": "2025-04", "price": 749 },
    { "date": "2025-05", "price": 699 }
  ],
  "analysis": "近期价格在 699-749 元之间波动，建议关注 618 大促期间是否有更低价格。"
}
```

---

### 7. 生成决策报告

```http
POST /api/v1/report
```

基于对话上下文生成结构化购买决策报告。

**请求体**：

```json
{
  "session_id": "abc123"
}
```

**响应体**：

```json
{
  "optimal_choice": {
    "name": "Nike Dunk Low",
    "reason": "性价比最高，近期价格稳定"
  },
  "alternatives": [
    { "name": "Nike Air Force 1", "reason": "经典款，适合日常穿搭" }
  ],
  "ai_advice": "建议优先考虑 Nike Dunk Low...",
  "session_id": "abc123"
}
```

---

## 错误码

| 状态码 | 说明 | 示例场景 |
|--------|------|---------|
| `200` | 成功 | 正常返回 |
| `400` | 请求参数错误 | 缺少 image 字段 |
| `422` | 参数校验失败 | JSON 格式不正确 |
| `500` | 服务端内部错误 | AI 模型调用超时 |
| `503` | 服务不可用 | 火山引擎 API 限流 |

**错误响应格式**：

```json
{
  "detail": "识别服务暂时不可用，请稍后重试"
}
```

---

## 交互式文档

启动后端服务后，访问以下地址查看 Swagger UI：

```
http://localhost:8000/docs
```

![Swagger UI 截图](../assets/swagger-ui.png)

> 注：截图需在本地启动后端后截取。

---

*文档版本：v1.0 | 最后更新：2025-06-07*
