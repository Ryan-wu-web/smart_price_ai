# Day 10 五大问题修复 — 设计规格

> 日期：2025-06-01
> 范围：ProductCard 图片加载、多目标识别真实化、识别速度优化、AI 上下文优化、Mock 数据扩充
> UI 设计参考：frontend-design skill — 与现有 Design Token 体系保持一致

---

## 架构概览

本次改动覆盖前后端共 8+ 个文件，分为 5 个修复模块：

```
修复1（图片加载） ──→ product_card.dart — Image.network 替换 Icon

修复2（多目标识别） ─┬─→ backend: recognize.py 新增 multi 路由
                    ├─→ backend: recognition.py 新增 recognize_multiple()
                    ├─→ frontend: api_service.dart 新增 recognizeMultiple()
                    └─→ frontend: multi_object_screen.dart 全面重写

修复3（识别速度） ──┬─→ backend: recognition.py — 合并 VLM+LLM 为主路径
                    ├─→ backend: recognition.py — 保留两阶段 fallback
                    └─→ frontend: home_screen.dart — maxWidth 1200→800

修复4（AI上下文） ──┬─→ backend: chat.py — 阈值 12→8，保留 6 条
                    └─→ backend: prompt_engine.py — context[-6:]→[-8:]

修复5（Mock数据） ──→ backend: comparison.py — 增加饮料/日用品
```

---

## 修复1：ProductCard 图片加载

### 问题
`product_card.dart` 第43行只显示 `Icon(Icons.image)`，完全没使用 `product.imageUrl`。

### 方案
将图标替换为 `Image.network`，增加 errorBuilder 处理加载失败：
- 图片尺寸：保持现有的 `screenWidth * 0.22`（clamp 80-120）
- 圆角：`Constants.mediumRadius`
- 加载中：显示浅灰色占位 + shimmer 效果（可选）
- 加载失败：回退到原 `Icons.image`
- 点击：保持现有 `onTap` 行为

### UI Token 一致性
- 使用 `ClipRRect` + `BorderRadius.circular(Constants.mediumRadius)`
- 占位背景使用 `Constants.placeholderGradient`

---

## 修复2：多目标识别真实化（重点设计）

### 问题
当前 `multi_object_screen.dart` 使用硬编码假数据（白色运动鞋/黑色背包/红色帽子），没有调用任何识别 API。

### 交互流程
```
HomeScreen 点击"多目标识别" → 打开相机 → 拍照
  → 显示 MultiObjectScreen（全屏照片 + 扫描线遮罩）
  → 调用后端 /api/v1/recognize/multi
  → 后端返回检测框列表（含 name/brand/category/bbox）
  → 前端渲染检测框动画（stagger ripple）
  → 用户点击检测框 → 跳转 ResultScreen（带入识别结果）
  → ResultScreen 有"查看同款低价"按钮 → 跳转 CompareScreen
```

### UI 设计（frontend-design 风格）

**页面结构**：
- 背景：全屏照片 `Image.file(fit: BoxFit.cover)`
- 暗化遮罩：`Colors.black.withOpacity(0.4)`（参考 ScanLineOverlay）
- 顶部状态栏：SafeArea + 品牌青渐变文字
  ```
  "检测到 3 个商品，点击识别"
  ```
  - 字体：白色，16px，FontWeight.bold
  - 阴影：`Shadow(color: black.withOpacity(0.6), blurRadius: 6)`

**检测框设计**：
- 边框：品牌青色（`Constants.brandColor`），2px
- 填充：`Constants.brandColor.withOpacity(0.15)`
- 圆角：`BorderRadius.circular(8)`
- 标签：品牌青色背景 pill，白色文字 12px bold
  ```dart
  Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Constants.brandColor,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(name, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
  )
  ```
- 入场动画：ripple 展开（`AnimatedBuilder` + `Interval` stagger），与现有页面一致

**加载状态**：
- 扫描线遮罩（复用 `ScanLineOverlay` 或类似组件）
- 品牌青脉冲圆点（复用 SearchScreen 中的 `_buildPulseDot`）
- 文字："AI 正在识别图中商品..."

**空状态**：
- 未检测到商品时，显示居中提示卡片：
  - 图标：`Icons.search_off`，品牌青色
  - 文字："未检测到商品"
  - 副文字："请尝试单目标识别"
  - 按钮："重新拍摄"（品牌渐变背景）

**点击反馈**：
- 检测框点击时：`scale 0.95 → 1.0`，150ms `easeSpring`
- 跳转 ResultScreen 使用 `MaterialPageRoute`

### 后端 API 设计

**新路由**：`POST /api/v1/recognize/multi`

**请求**：
```json
{"image_base64": "base64字符串"}
```

**响应**：
```json
{
  "objects": [
    {
      "name": "怡宝纯净水 2.08L",
      "brand": "怡宝",
      "category": "饮料",
      "color": "透明",
      "bbox": {"x": 0.15, "y": 0.25, "w": 0.4, "h": 0.5}
    },
    {
      "name": "水溶C100 西柚味 445ml",
      "brand": "农夫山泉",
      "category": "饮料",
      "color": "透明",
      "bbox": {"x": 0.6, "y": 0.3, "w": 0.25, "h": 0.45}
    }
  ]
}
```

**识别 Prompt**（单次调用，直接返回 JSON）：
```
你是一位专业的商品识别专家。请观察图片，识别图中所有独立的商品。
对每件商品，输出以下信息：
- name：商品名称
- brand：品牌（无法识别写"未知"）
- category：品类（如饮料、零食、日用品等）
- color：主色调
- bbox：检测框位置，格式为 {"x": 0-1, "y": 0-1, "w": 0-1, "h": 0-1}（相对图片的归一化坐标）

约束：
- 只输出 JSON 数组，不要任何解释文字
- 如果图中没有商品，输出空数组 []
- x,y 是检测框左上角坐标，w,h 是宽度和高度
```

---

## 修复3：识别速度优化

### 问题
当前识别流程串行调用 VLM + LLM 两次 API，总计 5-10 秒。

### 方案 C = A + B

**A. 合并 VLM+LLM 为主路径**

`recognition.py` 重写 `recognize()`：
- 主路径：直接调用 `llm_client.chat_json()`，messages 中包含图片 + Prompt
- Prompt 要求直接返回 `{name, brand, category, color, material, style}` JSON
- 不再需要 `vlm_client.describe_image()` 中间步骤

**Fallback 路径**：
- 如果单次调用返回格式不正确 / 解析失败
- 自动降级到原有两阶段流程（VLM 描述 + LLM 解析）
- 确保稳定性不下降

**预期效果**：减少 1 次 API 往返，节省 **2-4 秒**

**B. 前端图片压缩**
- `home_screen.dart`：`pickImage(maxWidth: 1200)` → `maxWidth: 800`
- 后端增加 base64 大小上限校验（5MB）

**预期效果**：上传时间减少 **30-50%**

---

## 修复4：AI 导购上下文优化

### 问题
对话超过 6 轮后摘要触发，早期信息丢失；上下文只保留最近 3 轮。

### 方案
- `chat.py`：`SUMMARY_THRESHOLD` 12 → 8（4轮后触发摘要）
- `chat.py`：摘要失败后保留 `context[-6:]`（3轮）而不是 `[-4:]`
- `prompt_engine.py`：`chat_reply` 的 `context[-6:]` → `[-8:]`（保留4轮）
- `prompt_engine.py`：摘要 Prompt 增加约束 — "保留所有商品名称、价格、平台信息"

---

## 修复5：其他物品精准度

### 问题
Mock 数据中饮料/日用品覆盖不足；识别失败后返回全部数据。

### 方案
- `comparison.py`：增加 15 款饮料/日用品数据（农夫山泉、怡宝、可乐、雪碧、红牛、薯片、方便面等）
- `comparison.py`：当搜索结果为空且非 fallback 时，返回空列表 `[]`
- `compare_screen.dart`：空结果时显示友好提示 + "试试搜索其他关键词"按钮

---

## 错误处理策略

| 场景 | 处理方式 |
|------|----------|
| 多目标识别返回空数组 | 显示"未检测到商品"提示卡片 + "重新拍摄"按钮 |
| 多目标识别 API 超时 | 显示"识别超时，请重试"SnackBar |
| 单次识别 fallback 也失败 | 返回原有错误提示"识别失败，请重试" |
| 图片加载失败（网络） | ProductCard 回退到 Icons.image |
| 搜索结果为空 | 显示"暂无比价结果"+ 推荐搜索其他关键词 |

---

## 测试策略

1. **多目标识别**：拍摄含 2-3 个商品的图片，验证检测框位置、名称准确性、点击跳转
2. **识别速度**：对比优化前后的识别耗时（计时）
3. **fallback 稳定性**：断网后恢复，验证识别是否正常工作
4. **图片加载**：进入 CompareScreen，验证所有卡片图片正常显示
5. **AI 多轮对话**：连续对话 10 轮，验证上下文连贯性
