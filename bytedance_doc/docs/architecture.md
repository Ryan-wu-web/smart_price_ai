<div align="center">

# 🏗️ Smart Price — 架构设计文档

<p align="center">
  <strong>系统架构 · 数据流 · 模块边界 · 技术选型</strong>
</p>

</div>

---

## 一、系统架构总览

Smart Price 采用经典的 **前后端分离架构**，客户端负责 UI 渲染与交互，服务端负责业务逻辑编排与 AI 任务调度，所有 AI 计算均在云端完成。

![系统架构图](../assets/system-architecture.png)

架构分为四层：

| 层级 | 职责 | 核心组件 |
|------|------|---------|
| **客户端层** | UI 渲染、摄像头采集、用户交互 | Flutter App |
| **服务端层** | 业务逻辑、AI 任务编排、数据聚合 | FastAPI（Recognition / Chat / Compare）|
| **AI 引擎层** | 视觉识别、语言生成、决策建议 | 火山引擎 Doubao-VLM / Doubao-LLM |
| **数据层** | 缓存、历史记录、模拟数据源 | SQLite + Mock Data |

---

## 二、数据流详解

### 2.1 拍照识物（单目标）

```
Flutter Camera ──base64──> Recognition Service ──HTTP──> Doubao-VLM
                                │                             │
                                │ dHash Key                   │ 识别结果
                                v                             v
                            SQLite Cache <────── 品牌/类目/颜色/款式
```

**流程说明**：
1. 用户拍摄商品照片，Flutter 将图片转为 base64
2. 后端先压缩图片（600px / JPEG 75%），计算 dHash 感知哈希作为缓存 key
3. 查询 SQLite 缓存：命中则直接返回，未命中则调用 Doubao-VLM
4. VLM 返回结构化识别结果（品牌、类目、颜色、款式）
5. 结果存入缓存，返回给前端展示

**优化点**：dHash 感知哈希可容忍重新拍照的角度、亮度差异，同一商品二次识别 **< 0.1 秒**。

---

### 2.2 AI 导购对话（SSE 流式）

```
Flutter ChatScreen <══SSE Stream══ Chat Service <══Stream══ Doubao-LLM
                                          │
                                          │ Session 上下文
                                          v
                                       SQLite Session
```

**流程说明**：
1. 用户发送消息，前端通过 HTTP POST 建立 SSE 连接
2. Chat Service 加载当前 session 的历史对话上下文
3. 调用 Doubao-LLM 流式接口，逐 token 接收回复
4. 后端实时解析 JSON 片段，提取 `reply` 字段，过滤换行符保护 SSE 格式
5. 将文本拆分为单字符，以 15ms 间隔逐个 yield，前端逐字追加渲染
6. 对话结束时返回 `action` 和 `action_data`，前端渲染决策卡片

**技术亮点**：字符级拆分 + 15ms 延迟，实现类 ChatGPT 的打字机效果。

---

### 2.3 多目标识别

```
Flutter Camera ──base64──> Recognition Service ──HTTP──> Doubao-VLM (多目标 Prompt)
                                                                   │
                                                                   │ 多个商品
                                                                   │ center{x,y}
                                                                   v
                                                            品牌/类目/颜色 + 坐标
```

**流程说明**：
1. 用户拍摄包含多个商品的照片
2. VLM 通过多目标 Prompt 识别画面中的所有商品，返回每个商品的属性 + 中心坐标
3. 后端将归一化坐标转为屏幕坐标
4. 前端执行智能布局算法：
   - 初始位置：气泡在锚点上方，水平居中
   - 上方空间不足 → 翻转到下方
   - 水平重叠 → 向下推移
   - 边缘越界 → 水平吸附
5. 气泡依次弹入（easeOutBack + 80ms stagger），锚点同步脉冲动画

---

## 三、模块边界与职责

### 3.1 客户端（Flutter）

| 模块 | 文件 | 职责 |
|------|------|------|
| 相机模块 | `camera_screen.dart` | 摄像头预览、拍摄、闪光灯控制 |
| 识别结果 | `result_screen.dart` | 展示识别属性、建议卡片、属性修正 |
| 多目标页 | `multi_object_screen.dart` | 气泡标签布局、动画、点击交互 |
| 比价页 | `compare_screen.dart` | 多平台商品列表、排序、筛选 |
| 聊天页 | `chat_screen.dart` | SSE 连接、逐字渲染、决策卡片 |
| 搜索页 | `search_screen.dart` | 关键词搜索、历史记录 |
| 历史页 | `history_screen.dart` | 识别历史列表、详情弹窗 |
| API 服务 | `api_service.dart` | 统一 HTTP 客户端、错误处理 |

**设计原则**：
- 纯 UI 层，不处理业务逻辑
- 状态管理采用 `StatefulWidget` + `setState`（项目规模适中，无需引入 BLoC/Riverpod）
- 所有 API 调用通过 `ApiService` 单例封装

---

### 3.2 服务端（FastAPI）

| 模块 | 文件 | 职责 |
|------|------|------|
| 识别服务 | `services/recognition.py` | 图片压缩、dHash 缓存、VLM 调用、结构化解析 |
| 聊天服务 | `services/chat.py` | Session 管理、上下文组装、LLM 流式调用、卡片生成 |
| 比价服务 | `services/compare_service.py` | 多平台数据聚合、排序、筛选 |
| API 客户端 | `core/base_api_client.py` | 火山引擎 API 统一封装、连接池复用 |
| 数据模型 | `models/` | Pydantic Schema、请求/响应校验 |
| 路由层 | `routers/` | FastAPI 路由定义、依赖注入 |

**设计原则**：
- 关注点分离：Service 处理业务，Router 处理 HTTP，Client 处理外部 API
- 可扩展性：`BaseAPIClient` 抽象层支持低成本替换 AI 模型
- 缓存策略：dHash 感知哈希 + SQLite，实现亚秒级缓存命中

---

### 3.3 AI 引擎层

| 模型 | 用途 | 输入 | 输出 |
|------|------|------|------|
| **Doubao-Seed-2.0-lite (VLM)** | 商品图像识别 | base64 图片 + 结构化 Prompt | 品牌、类目、颜色、款式、中心坐标 |
| **Doubao-Seed-2.0-lite (LLM)** | 对话生成 + 决策建议 | 历史对话 + 当前商品信息 + 系统 Prompt | 自然语言回复 + action/action_data |

**Prompt 设计策略**：
- 系统 Prompt 定义输出格式（JSON Schema），约束模型行为
- 识别 Prompt 区分单目标/多目标模式，返回不同结构
- 聊天 Prompt 注入当前商品信息，实现上下文感知导购
- 容错机制：JSON 解析失败时回退到正则提取，确保服务不中断

---

## 四、技术选型理由

### 4.1 为什么选 Flutter？

- **跨平台**：一套代码覆盖 Android/iOS，适合 MVP 快速验证
- **自绘引擎**：CustomPainter 支持气泡标签、扫描线等复杂自定义绘制
- **热重载**：开发效率高，适合 AI 辅助编码的快速迭代模式

### 4.2 为什么选 FastAPI？

- **异步原生**：`async/await` 支持高并发 SSE 流式响应
- **自动文档**：内置 Swagger/OpenAPI，API 文档零成本生成
- **类型安全**：Pydantic 模型确保请求/响应数据一致性

### 4.3 为什么选火山引擎 Doubao？

- **VLM + LLM 统一**：同一模型系列支持视觉识别和语言生成，降低对接成本
- **流式支持**：原生支持 SSE 流式输出，实现打字机效果
- **中文优化**：对中文商品名称、品牌名识别准确率高

### 4.4 为什么选 dHash 感知哈希？

- **重新拍照容忍**：差值哈希对亮度、角度、轻微裁剪变化不敏感
- **计算轻量**：9×8 像素灰度图即可计算，服务端毫秒级完成
- **存储高效**：64-bit 字符串作为 key，SQLite 查询极快

---

## 五、扩展性设计

### 5.1 接入新电商平台

`CompareService` 采用 Provider 模式，新增平台只需：
1. 实现 `BasePriceProvider` 接口
2. 在 `compare_service.py` 中注册
3. 无需修改前端代码

### 5.2 替换 AI 模型

`BaseAPIClient` 抽象了所有火山引擎 API 调用细节：
1. 修改 `settings.py` 中的 endpoint 和 api_key
2. 调整 `_build_payload()` 适配新模型的参数格式
3. 前端零感知

### 5.3 从模拟数据到真实数据

Mock 数据源通过 `MockDataProvider` 封装，替换为真实 API 时：
1. 实现 `BaseDataProvider` 接口
2. 在 `compare_service.py` 中切换 provider
3. 保留原有的排序、筛选逻辑不变

---

*文档版本：v1.0 | 最后更新：2025-06-07*
