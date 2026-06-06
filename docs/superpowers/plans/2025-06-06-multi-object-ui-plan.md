# 多目标识别结果页 UI 美化 + 动画微调 — 实现计划

> **给代理工作者：** 必需子skill：使用 subagent-driven-development（推荐）或 executing-plans 逐个任务执行此计划。步骤使用复选框（- [ ]）语法跟踪。

**目标：** 将 `multi_object_screen.dart` 气泡标签从品牌青渐变改为深色精致卡片风格，优化连接线、锚点和动画参数
**架构：** 纯样式参数调整，不引入新组件，不改布局算法和数据流
**技术栈：** Flutter 3.24.5，Dart

---

## 文件清单

| 文件 | 操作 | 职责 |
|------|------|------|
| `android-app/lib/screens/multi_object_screen.dart` | 修改 | 气泡标签样式、连接线样式、锚点样式、动画参数、背景 Vignette |

---

### 任务 1：调整气泡标签样式（背景、边框、阴影、内边距、宽度）

**文件：**
- 修改：`android-app/lib/screens/multi_object_screen.dart:486-519`

- [ ] **步骤 1：修改气泡 Container 的 decoration**

将气泡标签的 `BoxDecoration` 从品牌青渐变改为深蓝黑实体卡片：

```dart
decoration: BoxDecoration(
  color: const Color(0xFF1A1A2E).withOpacity(0.92),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(
    color: const Color(0xFF00B4D8).withOpacity(0.3),
    width: 1,
  ),
  boxShadow: [
    // 柔和品牌青外发光
    BoxShadow(
      color: const Color(0xFF00B4D8).withOpacity(0.15),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    // 紧凑下沉阴影
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ],
),
```

- [ ] **步骤 2：修改内边距和最大宽度**

```dart
constraints: const BoxConstraints(maxWidth: 160),
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
```

- [ ] **步骤 3：flutter analyze 检查**

运行：`cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app && flutter analyze`

预期：0 issues

- [ ] **步骤 4：提交**

```bash
cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app
git add lib/screens/multi_object_screen.dart
git commit -m "feat(6.6): 气泡标签改为深色精致卡片样式"
```

---

### 任务 2：反转序号圆点配色

**文件：**
- 修改：`android-app/lib/screens/multi_object_screen.dart:523-539`

- [ ] **步骤 1：修改序号圆点的背景色和文字色**

将序号圆点从"白底 + 品牌青数字"改为"品牌青底 + 白色数字"：

```dart
Container(
  width: 22,
  height: 22,
  decoration: const BoxDecoration(
    color: Constants.brandColor,  // 品牌青底
    shape: BoxShape.circle,
  ),
  child: Center(
    child: Text(
      '${bubble.index + 1}',
      style: const TextStyle(
        color: Colors.white,  // 白色数字
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),
```

- [ ] **步骤 2：flutter analyze 检查**

运行：`cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app && flutter analyze`

预期：0 issues

- [ ] **步骤 3：提交**

```bash
cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app
git add lib/screens/multi_object_screen.dart
git commit -m "feat(6.6): 序号圆点配色反转（品牌青底+白字）"
```

---

### 任务 3：连接线改为实线样式

**文件：**
- 修改：`android-app/lib/screens/multi_object_screen.dart:412-441`

- [ ] **步骤 1：修改连接线从渐变改为实线**

```dart
return Positioned(
  left: bubble.anchorX - 1,  // 宽度2px，居中
  top: top,
  child: Container(
    width: 2,
    height: height,
    decoration: BoxDecoration(
      color: Constants.brandColor.withOpacity(0.4),
      borderRadius: BorderRadius.circular(1),
    ),
  ),
);
```

- [ ] **步骤 2：flutter analyze 检查**

运行：`cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app && flutter analyze`

预期：0 issues

- [ ] **步骤 3：提交**

```bash
cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app
git add lib/screens/multi_object_screen.dart
git commit -m "feat(6.6): 连接线改为2px实线样式"
```

---

### 任务 4：锚点改为空心圆环

**文件：**
- 修改：`android-app/lib/screens/multi_object_screen.dart:390-409`

- [ ] **步骤 1：修改锚点为空心圆环**

```dart
return Positioned(
  left: bubble.anchorX - 4,  // 8px 圆环，居中
  top: bubble.anchorY - 4,
  child: Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: Colors.transparent,
      shape: BoxShape.circle,
      border: Border.all(
        color: Constants.brandColor,
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: Constants.brandColor.withOpacity(0.5),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ],
    ),
  ),
);
```

- [ ] **步骤 2：flutter analyze 检查**

运行：`cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app && flutter analyze`

预期：0 issues

- [ ] **步骤 3：提交**

```bash
cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app
git add lib/screens/multi_object_screen.dart
git commit -m "feat(6.6): 锚点改为8px空心圆环+品牌青描边"
```

---

### 任务 5：背景 Vignette 暗化加深

**文件：**
- 修改：`android-app/lib/screens/multi_object_screen.dart:380-388`

- [ ] **步骤 1：加深 Vignette 暗角**

```dart
Container(
  decoration: const BoxDecoration(
    gradient: RadialGradient(
      colors: [Colors.transparent, Color(0x60000000)],
      center: Alignment.center,
      radius: 0.80,
    ),
  ),
),
```

- [ ] **步骤 2：flutter analyze 检查**

运行：`cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app && flutter analyze`

预期：0 issues

- [ ] **步骤 3：提交**

```bash
cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app
git add lib/screens/multi_object_screen.dart
git commit -m "feat(6.6): Vignette暗角加深，突出气泡标签"
```

---

### 任务 6：调整动画参数（缓动、时长、stagger）

**文件：**
- 修改：`android-app/lib/screens/multi_object_screen.dart:94-98`（AnimationController）
- 修改：`android-app/lib/screens/multi_object_screen.dart:444-454`（AnimatedBuilder 中的曲线和 stagger）

- [ ] **步骤 1：修改 AnimationController 时长**

```dart
_controller = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 450),
);
```

- [ ] **步骤 2：修改 AnimatedBuilder 中的缓动和 stagger**

```dart
final delay = entry.key * 0.08;  // 80ms stagger
```

```dart
final adjustedValue = Curves.easeOutBack.transform(rawValue);
```

- [ ] **步骤 3：flutter analyze 检查**

运行：`cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app && flutter analyze`

预期：0 issues

- [ ] **步骤 4：提交**

```bash
cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app
git add lib/screens/multi_object_screen.dart
git commit -m "feat(6.6): 动画优化 - easeOutBack替代elasticOut, 450ms/80ms"
```

---

### 任务 7：新增锚点脉冲动画

**文件：**
- 修改：`android-app/lib/screens/multi_object_screen.dart:74-98`（添加 pulse controller）
- 修改：`android-app/lib/screens/multi_object_screen.dart:390-409`（锚点 pulse 动画）

- [ ] **步骤 1：添加脉冲动画控制器**

在 `_MultiObjectScreenState` 中添加：

```dart
late final AnimationController _pulseController;
```

在 `initState()` 中初始化：

```dart
_pulseController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 300),
);
```

在 `dispose()` 中释放：

```dart
_pulseController.dispose();
```

- [ ] **步骤 2：修改锚点为 AnimatedBuilder（脉冲效果）**

将锚点的 `Positioned` 包裹在 `AnimatedBuilder` 中，使用 `_pulseController` 驱动脉冲：

```dart
..._bubbles.asMap().entries.map((entry) {
  final bubble = entry.value;
  final delay = entry.key * 0.08;

  return AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final rawValue = ((_controller.value - delay) / (1 - delay))
          .clamp(0.0, 1.0);

      // 脉冲：仅在 adjustedValue 从 0 首次变为 >0 时触发
      if (rawValue > 0 && rawValue < 0.1 && _pulseController.status == AnimationStatus.dismissed) {
        _pulseController.forward(from: 0.0);
      }

      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseScale = 1.0 + (_pulseController.value * 0.5);
          final pulseOpacity = 1.0 - (_pulseController.value * 0.5);

          return Positioned(
            left: bubble.anchorX - 4 * pulseScale,
            top: bubble.anchorY - 4 * pulseScale,
            child: Opacity(
              opacity: pulseOpacity,
              child: Container(
                width: 8 * pulseScale,
                height: 8 * pulseScale,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Constants.brandColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Constants.brandColor.withOpacity(0.5 * pulseOpacity),
                      blurRadius: 8 * pulseScale,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}),
```

**注意：** 上面的嵌套 `AnimatedBuilder` 实现较复杂。更简洁的方式是只在外层 `AnimatedBuilder` 中根据 `_controller.value` 计算脉冲，不引入额外的 `_pulseController`。

简化方案：在气泡的 `AnimatedBuilder` 中同步计算锚点脉冲（使用同一个 `_controller` 和 delay）：

```dart
// 在气泡 AnimatedBuilder 的 builder 中，同时计算锚点脉冲
final pulsePhase = rawValue.clamp(0.0, 0.15) / 0.15;  // 前15%的动画时间内完成脉冲
final pulseScale = 1.0 + (pulsePhase < 1.0 ? pulsePhase * 0.5 : 0.0);
final pulseOpacity = 1.0 - (pulsePhase < 1.0 ? pulsePhase * 0.5 : 0.0);
```

然后锚点单独用一个 `AnimatedBuilder`：

```dart
..._bubbles.asMap().entries.map((entry) {
  final bubble = entry.value;
  final delay = entry.key * 0.08;

  return AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final rawValue = ((_controller.value - delay) / (1 - delay))
          .clamp(0.0, 1.0);
      final pulsePhase = rawValue.clamp(0.0, 0.15) / 0.15;
      final pulseScale = 1.0 + (pulsePhase < 1.0 ? pulsePhase * 0.5 : 0.0);
      final pulseOpacity = pulsePhase < 1.0
          ? 1.0 - pulsePhase * 0.5
          : 1.0;

      return Positioned(
        left: bubble.anchorX - 4 * pulseScale,
        top: bubble.anchorY - 4 * pulseScale,
        child: Opacity(
          opacity: pulseOpacity,
          child: Container(
            width: 8 * pulseScale,
            height: 8 * pulseScale,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: Constants.brandColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Constants.brandColor.withOpacity(0.5 * pulseOpacity),
                  blurRadius: 8 * pulseScale,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}),
```

- [ ] **步骤 3：flutter analyze 检查**

运行：`cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app && flutter analyze`

预期：0 issues

- [ ] **步骤 4：提交**

```bash
cd /c/Users/Lenovo/Desktop/super_test/smart-price-ai/android-app
git add lib/screens/multi_object_screen.dart
git commit -m "feat(6.6): 锚点脉冲动画 - 气泡弹出时同步脉冲一次"
```

---

## 自检

| 检查项 | 结果 |
|--------|------|
| 规格覆盖 | ✅ 设计文档中所有样式/动画调整均有对应任务 |
| 占位符扫描 | ✅ 无 TBD/TODO，所有代码为实际可用代码 |
| 类型一致性 | ✅ 文件路径、变量名、颜色值前后一致 |
