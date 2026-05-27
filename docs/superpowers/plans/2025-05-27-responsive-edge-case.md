# Day 6: 响应式适配 + 边缘 Case + 无障碍 + 后端异常中间件 — 实现计划

> **给代理工作者：** 必需子skill：使用 subagent-driven-development（推荐）或 executing-plans 逐个任务执行此计划。步骤使用复选框（- [ ]）语法跟踪。
> **执行原则：** 每个批次写完代码 → 严格审查 → `flutter analyze` 0 issues → `flutter build apk --debug` 成功 → `git commit` → `git push`。

**目标：** 消除前端硬编码尺寸、统一边缘 case 处理、添加后端全局异常中间件、基础无障碍支持
**架构：** 新增 `ResponsiveLayout` / `NetworkChecker` / `ErrorMessages` 工具类，各页面选择性引用；后端新增全局异常中间件兜底
**技术栈：** Flutter 3.24.5 + Dart 3.5.4 + connectivity_plus + Python/FastAPI

---

## 文件结构

```
android-app/lib/
├── widgets/
│   ├── responsive_layout.dart      # 新建：断点工具
│   └── suggestion_card.dart        # 修改：移除固定宽度 140
│   ├── product_card.dart           # 修改：图片相对尺寸
│   ├── shimmer_card.dart           # 修改：跟随 product_card
│   └── bottom_nav_bar.dart         # 修改：Semantics 标签
├── utils/
│   ├── error_messages.dart         # 新建：统一错误文案
│   └── network_checker.dart        # 新建：网络状态检测
├── screens/
│   ├── home_screen.dart            # 修改：响应式 + 权限捕获
│   ├── result_screen.dart          # 修改：响应式 + 弹窗焦点
│   ├── compare_screen.dart         # 修改：筛选标签 Wrap/ListView 切换
│   ├── trend_screen.dart           # 修改：走势图高度相对值
│   ├── splash_screen.dart          # 修改：横屏 Spacer 调整
│   └── chat_screen.dart            # 修改：决策卡片最大宽度限制
├── services/
│   └── api_service.dart            # 修改：网络检查 + 错误文案
└── pubspec.yaml                    # 修改：添加 connectivity_plus

backend/app/
├── middleware/
│   └── error_handler.py            # 新建：全局异常中间件
└── main.py                         # 修改：注册中间件
```

---

## 批次 1：基础设施（必须先完成，其他批次依赖）

### 任务 1.1：新建 `widgets/responsive_layout.dart`

**文件：**
- 创建：`android-app/lib/widgets/responsive_layout.dart`

- [ ] **步骤 1：编写代码**

```dart
import 'package:flutter/material.dart';

enum ScreenType { small, medium, large }

class ResponsiveLayout {
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return ScreenType.small;
    if (width < 420) return ScreenType.medium;
    return ScreenType.large;
  }

  static T value<T>(BuildContext context, {
    required T small,
    required T medium,
    required T large,
  }) {
    switch (getScreenType(context)) {
      case ScreenType.small:
        return small;
      case ScreenType.medium:
        return medium;
      case ScreenType.large:
        return large;
    }
  }
}
```

- [ ] **步骤 2：编译检查**

运行：`flutter analyze`

预期：`No issues found`

- [ ] **步骤 3：提交**

```bash
git add android-app/lib/widgets/responsive_layout.dart
git commit -m "feat(day6-infra): add ResponsiveLayout utility with 3 breakpoints"
```

---

### 任务 1.2：新建 `utils/error_messages.dart`

**文件：**
- 创建：`android-app/lib/utils/error_messages.dart`

- [ ] **步骤 1：编写代码**

```dart
class ErrorMessages {
  static const String timeout = '请求超时，请检查网络后重试';
  static const String serverError = '服务暂时不可用，请稍后重试';
  static const String noInternet = '网络不可用，请检查网络连接';
  static const String cameraDenied = '需要相机权限才能拍照识物';
  static const String recognizeFailed = '识别失败，请重试';
  static const String compareFailed = '比价失败，请重试';
  static const String chatFailed = '发送失败，请重试';
}
```

- [ ] **步骤 2：编译检查**

运行：`flutter analyze`

预期：`No issues found`

- [ ] **步骤 3：提交**

```bash
git add android-app/lib/utils/error_messages.dart
git commit -m "feat(day6-infra): add ErrorMessages utility for unified error copy"
```

---

### 任务 1.3：新建 `utils/network_checker.dart`

**文件：**
- 创建：`android-app/lib/utils/network_checker.dart`

- [ ] **步骤 1：修改 `pubspec.yaml` 添加依赖**

在 `dependencies:` 下添加：
```yaml
  connectivity_plus: ^5.0.2
```

- [ ] **步骤 2：运行 flutter pub get**

```bash
cd android-app && flutter pub get
```

预期：成功解析依赖

- [ ] **步骤 3：编写 network_checker.dart**

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkChecker {
  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
```

- [ ] **步骤 4：编译检查**

运行：`flutter analyze`

预期：`No issues found`

- [ ] **步骤 5：提交**

```bash
git add android-app/pubspec.yaml android-app/lib/utils/network_checker.dart
git commit -m "feat(day6-infra): add NetworkChecker with connectivity_plus"
```

---

### 任务 1.4：新建后端 `middleware/error_handler.py`

**文件：**
- 创建：`backend/app/middleware/error_handler.py`

- [ ] **步骤 1：编写代码**

```python
import logging
import traceback

from fastapi import Request
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)


async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.error(
        f"Unhandled exception at {request.method} {request.url.path}: {exc}\n"
        f"{traceback.format_exc()}"
    )
    return JSONResponse(
        status_code=500,
        content={
            "detail": "服务内部错误，请稍后重试",
            "code": "INTERNAL_ERROR",
            "path": str(request.url.path),
        },
    )
```

- [ ] **步骤 2：提交**

```bash
git add backend/app/middleware/error_handler.py
git commit -m "feat(day6-backend): add global exception middleware"
```

---

## 批次 2：组件层（可与批次 3/4/5 并行子代理执行）

### 任务 2.1：修改 `widgets/suggestion_card.dart`

**文件：**
- 修改：`android-app/lib/widgets/suggestion_card.dart`

**变更点：** 固定宽度 140 → `ResponsiveLayout.value` 三档宽度

- [ ] **步骤 1：添加 import**

```dart
import 'responsive_layout.dart';
```

- [ ] **步骤 2：修改 build 方法**

将：
```dart
return GestureDetector(
  onTap: onTap,
  child: Container(
    width: 140,
    margin: const EdgeInsets.only(right: 12),
```

替换为：
```dart
final cardWidth = ResponsiveLayout.value(context,
  small: 130.0,
  medium: 150.0,
  large: 170.0,
);

return GestureDetector(
  onTap: onTap,
  child: Container(
    width: cardWidth,
    margin: const EdgeInsets.only(right: 12),
```

- [ ] **步骤 3：编译检查**

运行：`flutter analyze`

预期：`No issues found`

- [ ] **步骤 4：提交**

```bash
git add android-app/lib/widgets/suggestion_card.dart
git commit -m "feat(day6-responsive): SuggestionCard adaptive width via ResponsiveLayout"
```

---

### 任务 2.2：修改 `widgets/product_card.dart`

**文件：**
- 修改：`android-app/lib/widgets/product_card.dart`

**变更点：** 商品图片固定 100x100 → `screenWidth * 0.22`（clamp 80-120）

- [ ] **步骤 1：修改图片容器**

将：
```dart
Container(
  width: 100,
  height: 100,
```

替换为：
```dart
final imageSize = (MediaQuery.of(context).size.width * 0.22).clamp(80.0, 120.0);

Container(
  width: imageSize,
  height: imageSize,
```

- [ ] **步骤 2：编译检查 + 提交**

```bash
flutter analyze
git add android-app/lib/widgets/product_card.dart
git commit -m "feat(day6-responsive): ProductCard image size relative to screen width"
```

---

### 任务 2.3：修改 `widgets/shimmer_card.dart`

**文件：**
- 修改：`android-app/lib/widgets/shimmer_card.dart`

**变更点：** 骨架图片 100x100 → 与 product_card 保持一致

- [ ] **步骤 1：修改骨架图片尺寸**

将 `width: 100, height: 100` 的 Container 替换为：
```dart
final imageSize = (MediaQuery.of(context).size.width * 0.22).clamp(80.0, 120.0);

Container(
  width: imageSize,
  height: imageSize,
```

- [ ] **步骤 2：编译检查 + 提交**

```bash
flutter analyze
git add android-app/lib/widgets/shimmer_card.dart
git commit -m "feat(day6-responsive): ShimmerCard image size sync with ProductCard"
```

---

### 任务 2.4：修改 `widgets/bottom_nav_bar.dart` — Semantics

**文件：**
- 修改：`android-app/lib/widgets/bottom_nav_bar.dart`

**变更点：** 给每个 tab 添加 Semantics 标签

- [ ] **步骤 1：包裹每个 tab 为 Semantics**

将每个 `GestureDetector` 包裹为：
```dart
Semantics(
  label: label,  // '首页', '历史', '聊天', '我的'
  button: true,
  child: GestureDetector(...),
)
```

其中 label 从 tabs 数组中获取。

- [ ] **步骤 2：编译检查 + 提交**

```bash
flutter analyze
git add android-app/lib/widgets/bottom_nav_bar.dart
git commit -m "a11y(day6): add Semantics labels to BottomNavBar tabs"
```

---

## 批次 3：首页 + 结果页（可与批次 2/4/5 并行）

### 任务 3.1：修改 `screens/home_screen.dart`

**文件：**
- 修改：`android-app/lib/screens/home_screen.dart`

**变更点 1：** 最近识别卡片宽度自适应
**变更点 2：** 拍照按钮 padding 自适应
**变更点 3：** 无摄像头权限捕获

- [ ] **步骤 1：添加 import**

```dart
import '../utils/error_messages.dart';
import '../widgets/responsive_layout.dart';
```

- [ ] **步骤 2：修改最近识别卡片宽度**

找到 `width: 140` 的 Container，替换为：
```dart
final recentCardWidth = ResponsiveLayout.value(context,
  small: 120.0,
  medium: 140.0,
  large: 160.0,
);

Container(
  width: recentCardWidth,
```

- [ ] **步骤 3：修改拍照按钮 padding**

找到拍照按钮的 `padding: EdgeInsets.all(28)`，替换为：
```dart
padding: EdgeInsets.all(ResponsiveLayout.value(context,
  small: 20.0,
  medium: 28.0,
  large: 36.0,
)),
```

- [ ] **步骤 4：修改 `_pickImage` 添加权限捕获**

在 `final picked = await picker.pickImage(...)` 外层添加：
```dart
try {
  final picked = await picker.pickImage(source: source, maxWidth: 1200);
  // ... 原有逻辑不变
} on PlatformException catch (e) {
  if (e.code == 'camera_access_denied') {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('需要相机权限'),
        content: const Text(ErrorMessages.cameraDenied),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
  return;
}
```

- [ ] **步骤 5：编译检查 + 提交**

```bash
flutter analyze
git add android-app/lib/screens/home_screen.dart
git commit -m "feat(day6): HomeScreen responsive cards/button + camera permission handling"
```

---

### 任务 3.2：修改 `screens/result_screen.dart`

**文件：**
- 修改：`android-app/lib/screens/result_screen.dart`

**变更点 1：** 图片容器高度相对值
**变更点 2：** 建议卡片列表高度自适应
**变更点 3：** 弹窗关闭后焦点返回

- [ ] **步骤 1：修改图片容器高度**

将 `height: 220` 替换为：
```dart
final imageHeight = (MediaQuery.of(context).size.height * 0.25).clamp(180.0, 280.0);

// Container 中
height: imageHeight,
```

- [ ] **步骤 2：修改建议卡片列表高度**

将 `height: 140` 的 `SizedBox` 替换为：
```dart
final listHeight = ResponsiveLayout.value(context,
  small: 130.0,
  medium: 140.0,
  large: 150.0,
);

SizedBox(
  height: listHeight,
```

- [ ] **步骤 3：弹窗焦点管理**

在 `_editAttribute` 的 `showDialog` 中，确认按钮 onPressed 添加：
```dart
onPressed: () {
  onConfirm(controller.text);
  Navigator.pop(context);
  // 焦点返回
  Future.delayed(const Duration(milliseconds: 100), () {
    FocusScope.of(context).requestFocus(FocusNode());
  });
},
```

- [ ] **步骤 4：编译检查 + 提交**

```bash
flutter analyze
git add android-app/lib/screens/result_screen.dart
git commit -m "feat(day6): ResultScreen responsive image/list height + focus management"
```

---

## 批次 4：其他页面（可与批次 2/3/5 并行）

### 任务 4.1：修改 `screens/compare_screen.dart`

**文件：**
- 修改：`android-app/lib/screens/compare_screen.dart`

**变更点：** 筛选标签在大屏下用 Wrap 代替横向 ListView

- [ ] **步骤 1：添加 import**

```dart
import '../widgets/responsive_layout.dart';
```

- [ ] **步骤 2：修改筛选标签区域**

找到筛选标签的 `ListView`（横向滚动），用 `LayoutBuilder` 包裹：
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final tags = [
      _buildFilterChip('全部'),
      _buildFilterChip('京东'),
      _buildFilterChip('淘宝'),
      _buildFilterChip('拼多多'),
    ];
    if (constraints.maxWidth > 420) {
      return Wrap(spacing: 10, children: tags);
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: tags,
      ),
    );
  },
)
```

- [ ] **步骤 3：编译检查 + 提交**

```bash
flutter analyze
git add android-app/lib/screens/compare_screen.dart
git commit -m "feat(day6): CompareScreen filter tags use Wrap on large screens"
```

---

### 任务 4.2：修改 `screens/trend_screen.dart`

**文件：**
- 修改：`android-app/lib/screens/trend_screen.dart`

**变更点：** 走势图高度 220 → `screenHeight * 0.28`

- [ ] **步骤 1：修改走势图高度**

将 `_buildChartPlaceholder` 中的 `height: 220` 替换为：
```dart
final chartHeight = (MediaQuery.of(context).size.height * 0.28).clamp(180.0, 300.0);

// Container 中
height: chartHeight,
```

- [ ] **步骤 2：编译检查 + 提交**

```bash
flutter analyze
git add android-app/lib/screens/trend_screen.dart
git commit -m "feat(day6): TrendScreen chart height relative to screen"
```

---

### 任务 4.3：修改 `screens/splash_screen.dart`

**文件：**
- 修改：`android-app/lib/screens/splash_screen.dart`

**变更点：** 横屏时减少 Spacer flex

- [ ] **步骤 1：修改 Spacer flex**

将 `Spacer(flex: 3)` 和 `Spacer(flex: 4)` 替换为：
```dart
final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
final topFlex = isLandscape ? 1 : 3;
final bottomFlex = isLandscape ? 2 : 4;

// 在 Column children 中
Spacer(flex: topFlex),
// ... 中间内容 ...
Spacer(flex: bottomFlex),
```

- [ ] **步骤 2：编译检查 + 提交**

```bash
flutter analyze
git add android-app/lib/screens/splash_screen.dart
git commit -m "feat(day6): SplashScreen reduce Spacer flex in landscape"
```

---

### 任务 4.4：修改 `screens/chat_screen.dart`

**文件：**
- 修改：`android-app/lib/screens/chat_screen.dart`

**变更点：** 决策卡片最大宽度限制为 600px + Center

- [ ] **步骤 1：包裹决策卡片**

找到决策卡片的 Container（`margin: EdgeInsets.symmetric(horizontal: 16)`），在外层包裹：
```dart
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 600),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      // ... 其余不变
    ),
  ),
)
```

- [ ] **步骤 2：编译检查 + 提交**

```bash
flutter analyze
git add android-app/lib/screens/chat_screen.dart
git commit -m "feat(day6): ChatScreen decision card max width 600px on large screens"
```

---

## 批次 5：API 层 + 边缘 Case（可与批次 2/3/4 并行）

### 任务 5.1：修改 `services/api_service.dart`

**文件：**
- 修改：`android-app/lib/services/api_service.dart`

**变更点 1：** 请求前检查网络
**变更点 2：** 统一错误文案使用 `ErrorMessages`

- [ ] **步骤 1：添加 import**

```dart
import '../utils/error_messages.dart';
import '../utils/network_checker.dart';
```

- [ ] **步骤 2：在基类请求方法中添加网络检查**

找到 `_post` 或基类请求方法，在发送请求前添加：
```dart
final isOnline = await NetworkChecker.isOnline();
if (!isOnline) {
  throw ApiException(ErrorMessages.noInternet);
}
```

- [ ] **步骤 3：替换硬编码错误文案**

将所有超时/错误的硬编码文案替换为 `ErrorMessages.xxx`。

例如：
```dart
// 替换前
timeout: const Duration(seconds: 30),
).onError((error, stackTrace) {
  throw ApiException('请求超时，请检查网络后重试');
});

// 替换后
timeout: const Duration(seconds: 30),
).onError((error, stackTrace) {
  throw ApiException(ErrorMessages.timeout);
});
```

- [ ] **步骤 4：编译检查 + 提交**

```bash
flutter analyze
git add android-app/lib/services/api_service.dart
git commit -m "feat(day6): ApiService network pre-check + unified ErrorMessages"
```

---

### 任务 5.2：修改 `screens/home_screen.dart` — 弹窗焦点

**文件：**
- 修改：`android-app/lib/screens/home_screen.dart`

**变更点：** `_showImageSourceDialog` 关闭后焦点返回

- [ ] **步骤 1：修改弹窗关闭逻辑**

在 `showModalBottomSheet` 的 builder 中，每个选项的 `onTap` 添加：
```dart
onTap: () {
  Navigator.pop(context);
  // 延迟一帧确保弹窗已关闭
  Future.delayed(Duration.zero, () {
    FocusScope.of(context).requestFocus(FocusNode());
  });
  _pickImage(ImageSource.camera);
},
```

- [ ] **步骤 2：编译检查 + 提交**

```bash
flutter analyze
git add android-app/lib/screens/home_screen.dart
git commit -m "a11y(day6): return focus after image source dialog closes"
```

---

## 批次 6：后端注册 + 全局验证（必须在所有前端批次完成后执行）

### 任务 6.1：修改 `backend/app/main.py` 注册中间件

**文件：**
- 修改：`backend/app/main.py`

- [ ] **步骤 1：添加 import**

```python
from app.middleware.error_handler import global_exception_handler
```

- [ ] **步骤 2：注册异常处理器**

在 `app = FastAPI(...)` 之后添加：
```python
app.add_exception_handler(Exception, global_exception_handler)
```

- [ ] **步骤 3：后端启动测试**

```bash
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

预期：正常启动，无报错

- [ ] **步骤 4：提交**

```bash
git add backend/app/main.py
git commit -m "feat(day6-backend): register global exception handler in FastAPI"
```

---

### 任务 6.2：全局编译验证

- [ ] **步骤 1：Flutter 静态分析**

```bash
cd android-app && flutter analyze
```

预期：`No issues found`

- [ ] **步骤 2：Flutter APK 构建**

```bash
cd android-app && flutter build apk --debug
```

预期：`Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **步骤 3：后端测试**

```bash
cd backend && pytest tests/ -v
```

预期：全部通过

- [ ] **步骤 4：提交 handoff-prompt 更新**

```bash
git add docs/handoff-prompt.md
git commit -m "docs(day6): update handoff-prompt with Day 6 completion summary"
```

- [ ] **步骤 5：推送到 GitHub**

```bash
git push origin main
```

---

## 执行批次与并行策略

```
批次 1: 基础设施 ───────────────────────────────────────┐
  (responsive_layout + error_messages + network_checker   │
   + error_handler + pubspec.yaml)                        │
  → 审查 → commit → push                                  │
                                                          │
批次 2: 组件层 ──────────────────┐                       │
  (suggestion_card + product_card │                       │
   + shimmer_card + bottom_nav_bar)                      │
  → 审查 → commit → push                                  │ 并行
                                                          │ (子代理)
批次 3: 首页+结果页 ─────────────┤                       │
  (home_screen + result_screen)  │                       │
  → 审查 → commit → push                                  │
                                                          │
批次 4: 其他页面 ────────────────┤                       │
  (compare + trend + splash + chat)                      │
  → 审查 → commit → push                                  │
                                                          │
批次 5: API层+边缘case ──────────┤                       │
  (api_service + home_screen焦点)                        │
  → 审查 → commit → push                                  │
                                                          ▼
批次 6: 后端注册 + 全局验证 ──────────────────────────────┘
  (main.py注册 + flutter analyze + build apk + pytest
   + handoff更新 + push)
  → 审查 → commit → push
```

**子代理分配建议：**
- **子代理 A**：批次 2（组件层，4 个文件，互相关联）
- **子代理 B**：批次 3（首页+结果页，2 个文件）
- **子代理 C**：批次 4（其他页面，4 个文件，互不关联，可并行内部）
- **子代理 D**：批次 5（API 层 + 焦点管理，2 个文件）

**批次 1 和批次 6 由主代理执行**（涉及基础设施和全局验证，需要主上下文）。

---

## 自检

1. **规格覆盖：** 设计文档中的 6 大节（响应式 10 项 + 边缘 case 3 项 + 后端中间件 + 无障碍 2 项）均有对应任务。
2. **占位符扫描：** 无 TBD/TODO，每个步骤都有完整代码和预期输出。
3. **类型一致性：** `ResponsiveLayout.value` 的返回类型 `T` 在各使用处一致；`ErrorMessages` 全为 `String` const。

---

*计划完成并保存到 `docs/superpowers/plans/2025-05-27-responsive-edge-case.md`。*
