# 多目标识别重写 — 设计规格（方案 A）

> 日期：2025-06-02
> 方案：保留 bbox，后端限制 + 前端纯边框

---

## 核心原则

BBOX 框不需要完全精确覆盖商品，只需要框在商品区域内，让用户意识到"这一块指的是整个商品"。

---

## 后端改动

### 文件：`backend/app/services/recognition.py`

**新增 `_sanitize_bboxes()` 方法：**

对 LLM 返回的每个 bbox 进行后处理：

1. **限制最大尺寸**：`w = min(w, 0.5)`, `h = min(h, 0.5)`（最大占屏幕 50%）
2. **限制最小尺寸**：`w = max(w, 0.15)`, `h = max(h, 0.15)`（最小占屏幕 15%，避免框太小看不见）
3. **防止重叠**：如果两个框 IOU > 0.3，将第二个框向 x 方向偏移 0.05
4. **限制不越界**：`x + w ≤ 1.0`, `y + h ≤ 1.0`

**修改 `recognize_multiple()`：**
- 在解析 `result` 后，调用 `_sanitize_bboxes(objects)`

---

## 前端改动

### 文件：`android-app/lib/screens/multi_object_screen.dart`

**检测框 UI（纯边框，无填充）：**

```dart
// 外层：白色 3px 边框 + 发光阴影
Container(
  decoration: BoxDecoration(
    border: Border.all(color: Colors.white, width: 3),
    borderRadius: BorderRadius.circular(6),
    boxShadow: [
      BoxShadow(
        color: boxColor.withOpacity(0.6),
        blurRadius: 12,
        spreadRadius: 2,
      ),
    ],
  ),
)

// 内层：品牌青 2px 边框（形成双层边框效果）
Container(
  margin: EdgeInsets.all(2),
  decoration: BoxDecoration(
    border: Border.all(color: boxColor, width: 2),
    borderRadius: BorderRadius.circular(4),
  ),
)
```

**标签位置（框上方）：**
- 使用 `Column`：标签在上，检测框在下
- 标签背景：品牌青（或交替色），圆角 4px
- 标签内容：白色序号圆圈 + 商品名

**交替颜色：**
- 奇数框：品牌青 `#00B4D8`
- 偶数框：橙色 `#FF6B6B`

**溢出处理：**
- `top + height ≤ screenHeight`
- `left + width ≤ screenWidth`
- 超出时自动缩小或贴边

---

## 测试策略

1. 后端单元测试：测试 `_sanitize_bboxes()` 各种边界 case
2. Flutter analyze：0 issues
3. 真机测试：拍怡宝+资生堂，验证框不覆盖全屏、不重叠、标签可见

---

## 文件清单

| 文件 | 改动类型 |
|------|---------|
| `backend/app/services/recognition.py` | 修改：新增 `_sanitize_bboxes()` |
| `android-app/lib/screens/multi_object_screen.dart` | 重写：检测框 UI |
