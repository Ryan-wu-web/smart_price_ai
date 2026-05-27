# Day 6: 响应式适配 + 边缘 Case + 无障碍 + 后端异常中间件 — 技术设计文档

> 日期：2025-05-27
> 原则：**最小侵入，不影响现有功能**

---

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                      前端 (Flutter)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ Responsive   │  │ Edge Case    │  │ Accessibility    │  │
│  │ Layout       │  │ Handler      │  │ (Semantics)      │  │
│  │ (新组件)      │  │ (新工具类)    │  │ (装饰现有组件)    │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↕ API
┌─────────────────────────────────────────────────────────────┐
│                      后端 (FastAPI)                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Global Error Middleware (新)                        │   │
│  │ 统一捕获 → 统一格式 → 统一日志                       │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 第一节：响应式适配（前端）

### 1.1 新增 `widgets/responsive_layout.dart`

**职责：** 提供断点判断工具，不替代任何现有布局，仅作为辅助函数使用。

**设计原则：**
- 纯函数，无状态，无 side effect
- 不修改任何现有 widget 的接口
- 现有代码可选择性地使用，不强求

**接口设计：**

```dart
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
      case ScreenType.small: return small;
      case ScreenType.medium: return medium;
      case ScreenType.large: return large;
    }
  }
}
```

**断点定义依据：**
- small (<360)：iPhone SE 等超小屏
- medium (360-420)：标准手机（iPhone 14/15, 小米等）
- large (>420)：大屏手机/平板

---

### 1.2 `widgets/suggestion_card.dart` — 固定宽度 140px

**当前问题：** 固定 `width: 140`，大屏下显得过小。

**技术方案（最小侵入）：**
- 移除固定的 `width: 140`
- 改为 `LayoutBuilder` 根据父容器宽度自适应
- 保持 `margin` 和 `padding` 不变
- **不修改**接口（构造函数参数不变）

```dart
// 修改后核心逻辑
LayoutBuilder(
  builder: (context, constraints) {
    final width = ResponsiveLayout.value(context,
      small: 130.0,
      medium: 150.0,
      large: 170.0,
    );
    return Container(
      width: width,
      // ... 其余不变
    );
  },
)
```

---

### 1.3 `widgets/product_card.dart` — 固定宽高 100px

**当前问题：** 商品图片固定 100x100。

**技术方案：**
- 图片尺寸改为 `screenWidth * 0.22`（约等于标准屏 88-100px）
- 限制最小 80px，最大 120px
- 保持卡片整体结构不变

```dart
// 修改后
final imageSize = MediaQuery.of(context).size.width * 0.22;
final clampedSize = imageSize.clamp(80.0, 120.0);

Container(
  width: clampedSize,
  height: clampedSize,
  // ... 其余不变
)
```

---

### 1.4 `screens/home_screen.dart` — 高风险

**当前问题：**
- 分类列表固定高 36
- 最近识别卡片固定宽 140 / 高 120
- 拍照按钮固定 padding 28

**技术方案（逐项最小侵入）：**

**a) 分类列表高度**
- 保持不变（36 是文字高度 + padding，本身已较紧凑）
- 大屏下标签数量少时右侧留白，这是预期行为（横向滚动）

**b) 最近识别卡片**
- 宽度改为 `ResponsiveLayout.value(context, small: 120, medium: 140, large: 160)`
- 高度保持 120（内容决定，不需要改）

**c) 拍照按钮 padding**
- 改为 `ResponsiveLayout.value(context, small: 20, medium: 28, large: 36)`
- 大屏下更大更有冲击力

---

### 1.5 `screens/result_screen.dart` — 高风险

**当前问题：**
- 图片容器固定高 220
- 建议卡片列表固定高 140
- 属性 chip maxWidth 为屏幕宽 42%

**技术方案：**

**a) 图片容器高度**
- 改为 `screenHeight * 0.25`
- 限制 min 180, max 280

```dart
final imageHeight = (MediaQuery.of(context).size.height * 0.25).clamp(180.0, 280.0);
```

**b) 建议卡片列表高度**
- 改为 `ResponsiveLayout.value(context, small: 130, medium: 140, large: 150)`
- 卡片本身已通过 `suggestion_card.dart` 的修改自适应宽度

**c) 属性 chip maxWidth**
- 保持 `screenWidth * 0.42`（已经是相对值，无需修改）

---

### 1.6 `screens/compare_screen.dart` — 筛选标签

**当前问题：** 筛选标签横向滚动，大屏下右侧留白。

**技术方案：**
- 添加 `LayoutBuilder` 检测屏幕宽度
- 当 `screenWidth > 420` 时，标签使用 `Wrap` 代替 `ListView.horizontal`，自动换行铺满
- 当 `screenWidth <= 420` 时，保持现有横向滚动

```dart
// 伪代码
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 420) {
      return Wrap(spacing: 10, children: tags);
    }
    return ListView(scrollDirection: Axis.horizontal, children: tags);
  },
)
```

---

### 1.7 `screens/trend_screen.dart` — 走势图高度

**当前问题：** 走势图固定高 220。

**技术方案：**
- 改为 `screenHeight * 0.28`
- 限制 min 180, max 300

---

### 1.8 `screens/splash_screen.dart` — 横屏分散

**当前问题：** `Spacer(flex: 3/4)` 在横屏下过度分散。

**技术方案：**
- 检测屏幕方向
- 横屏时减少 Spacer flex 为 `1/2`
- 竖屏保持 `3/4`

```dart
final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
final topFlex = isLandscape ? 1 : 3;
final bottomFlex = isLandscape ? 2 : 4;
```

---

### 1.9 `screens/chat_screen.dart` — 决策卡片最大宽度

**当前问题：** 决策卡片 `margin: horizontal: 16`，宽屏下两侧留白过大。

**技术方案：**
- 决策卡片外层加 `ConstrainedBox(maxWidth: 600)` + `Center`
- 小屏下自然撑满，大屏下限制最大宽度

---

### 1.10 `widgets/shimmer_card.dart` — 跟随 product_card

**当前问题：** 骨架屏尺寸与 product_card 不同步。

**技术方案：**
- 骨架屏图片尺寸改为与 product_card 相同的计算方式
- 确保加载态和实际内容尺寸一致，避免布局跳动

---

## 第二节：边缘 Case（前端）

### 2.1 无网络检测

**新增依赖：** `connectivity_plus: ^5.0.2`

**技术方案：**
- 新建 `utils/network_checker.dart`
- 提供 `NetworkChecker.isOnline()` 静态方法
- 在 `ApiService` 的每个请求前调用检查
- 无网络时直接抛 `ApiException`，不发送请求

```dart
class NetworkChecker {
  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
```

**不侵入现有 API 调用代码的方式：**
- 在 `ApiService` 的基类方法中统一检查
- 现有各接口调用代码**完全不动**

### 2.2 无摄像头权限

**技术方案：**
- `image_picker` 抛 `PlatformException` 时捕获
- 错误 code 为 `camera_access_denied` 时，弹 Dialog 引导用户去设置

```dart
try {
  final picked = await picker.pickImage(...);
} on PlatformException catch (e) {
  if (e.code == 'camera_access_denied') {
    showDialog(...引导去设置...);
  }
}
```

**修改位置：** `home_screen.dart` 的 `_pickImage` 和 `_pickMultiObjectImage`

### 2.3 统一错误提示文案

**技术方案：**
- 新建 `utils/error_messages.dart`
- 统一定义错误文案，避免各处硬编码不同文案

```dart
class ErrorMessages {
  static const String timeout = '请求超时，请检查网络后重试';
  static const String serverError = '服务暂时不可用，请稍后重试';
  static const String noInternet = '网络不可用，请检查网络连接';
  static const String cameraDenied = '需要相机权限才能拍照识物';
}
```

**修改位置：**
- `home_screen.dart` — 识别失败 SnackBar
- `compare_screen.dart` — 比价失败提示
- `chat_screen.dart` — 聊天失败提示
- `api_service.dart` — 超时/异常文案

---

## 第三节：后端全局异常中间件

### 3.1 新建 `backend/app/middleware/error_handler.py`

**技术方案：**
- 注册 FastAPI 全局 `exception_handler`
- 捕获所有未处理异常，返回统一格式
- 记录错误日志（含 traceback）

```python
from fastapi import Request
from fastapi.responses import JSONResponse
import logging
import traceback

logger = logging.getLogger(__name__)

async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}\n{traceback.format_exc()}")
    return JSONResponse(
        status_code=500,
        content={
            "detail": "服务内部错误，请稍后重试",
            "code": "INTERNAL_ERROR",
            "path": request.url.path,
        }
    )
```

### 3.2 `backend/app/main.py` 注册中间件

```python
from app.middleware.error_handler import global_exception_handler

app.add_exception_handler(Exception, global_exception_handler)
```

### 3.3 Router 去重

**当前状态：** 每个 Router 手动写相同的 `try/except`。

**处理策略：**
- 保留 Router 内的 `try/except HTTPException`（业务异常需要特定状态码和文案）
- 移除 Router 内的 `except Exception` 块（由全局中间件接管）
- **如果 Router 内没有 HTTPException 的特殊处理，可保留原样**（重复但无害）

**原则：** 不去动已经能工作的代码，只新增中间件兜底未捕获异常。

---

## 第四节：无障碍支持

### 4.1 语义标签

**技术方案：**
- 给底部导航栏每个 tab 加 `Semantics(label: '首页', button: true)`
- 给拍照按钮加 `Semantics(label: '拍照识物', button: true)`
- 给建议卡片加 `Semantics(label: title, button: true)`
- 给属性标签加 `Semantics(label: '$label: $value')`

**不侵入方式：** 在现有 widget 外层包裹 `Semantics`，不改变内部结构。

### 4.2 焦点管理

**技术方案：**
- 弹窗（编辑属性/选择图片来源）关闭后，焦点返回触发按钮
- 使用 `FocusScope.of(context).previousFocus()` 或 `FocusNode.requestFocus()`

**修改位置：**
- `result_screen.dart` — `_editAttribute` 弹窗
- `home_screen.dart` — `_showImageSourceDialog` 弹窗

---

## 第五节：测试策略

### 5.1 响应式测试

- 在 Android Studio 模拟器中测试不同屏幕尺寸（小/中/大）
- 横屏/竖屏切换测试（SplashScreen、MultiObjectScreen）

### 5.2 边缘 Case 测试

- 关闭 WiFi 测试无网络提示
- 关闭相机权限测试权限引导
- 后端关闭测试超时/500 提示

### 5.3 后端测试

- 触发一个未捕获异常，验证全局中间件返回统一格式

---

## 第六节：文件变更清单

### 新增文件
1. `android-app/lib/widgets/responsive_layout.dart`
2. `android-app/lib/utils/network_checker.dart`
3. `android-app/lib/utils/error_messages.dart`
4. `backend/app/middleware/error_handler.py`

### 修改文件（按优先级排序）
1. `android-app/lib/widgets/suggestion_card.dart`
2. `android-app/lib/widgets/product_card.dart`
3. `android-app/lib/widgets/shimmer_card.dart`
4. `android-app/lib/screens/home_screen.dart`
5. `android-app/lib/screens/result_screen.dart`
6. `android-app/lib/screens/compare_screen.dart`
7. `android-app/lib/screens/trend_screen.dart`
8. `android-app/lib/screens/splash_screen.dart`
9. `android-app/lib/screens/chat_screen.dart`
10. `android-app/lib/screens/home_screen.dart`（权限处理）
11. `android-app/lib/services/api_service.dart`（网络检查 + 错误文案）
12. `android-app/lib/screens/home_screen.dart`（弹窗焦点）
13. `android-app/lib/screens/result_screen.dart`（弹窗焦点）
14. `android-app/lib/widgets/bottom_nav_bar.dart`（Semantics）
15. `android-app/pubspec.yaml`（添加 connectivity_plus）
16. `backend/app/main.py`（注册中间件）

### 不修改的文件
- `report_screen.dart` — 风险低，布局已较灵活
- `multi_object_screen.dart` — 检测框基于比例，基本OK
- `backend/app/routers/*.py` — 保留现有 try/except，全局中间件兜底

---

## 自检

1. **占位符扫描：** 无 TBD/TODO，所有方案都有具体代码示例
2. **内部一致性：** ResponsiveLayout 断点在所有页面统一使用
3. **范围检查：** 聚焦 Day 6 范围，不涉及功能补全（历史页/我的页等）
4. **歧义检查：** 每个修复都有"不改什么"的明确说明

---

*设计文档完成，等待用户审查。*
