# Day 2：Flutter 前端 — 用户看到的一切

> 目标：理解 Flutter 的基本概念，以及项目中相机、气泡标签、聊天页面是怎么实现的。

---

## 1. Flutter 是什么？

Flutter 是 Google 出的**跨平台 UI 框架**。写一套 Dart 代码，可以同时生成 Android 和 iOS App。

**核心特点**：
- 自己画 UI（不依赖系统原生组件），所以不同手机上看起来一样
- 热重载：改代码后秒看效果
- 万物皆 Widget：按钮是 Widget、文字是 Widget、整个页面也是 Widget

---

## 2. Widget 是什么？（最重要概念）

Widget = **乐高积木**。你用小积木（按钮、文字）搭出大积木（页面），大积木再搭出整个 App。

**两种 Widget**：

| 类型 | 比喻 | 特点 | 例子 |
|------|------|------|------|
| **StatelessWidget** | 纸质说明书 | 内容固定，不会变 | 展示用的文字、图标 |
| **StatefulWidget** | 电子墨水屏 | 内容会变，有"状态" | 计数器、输入框、聊天列表 |

**项目中哪里用了 StatefulWidget？**
- `ChatScreen`：消息列表会不断增加
- `MultiObjectScreen`：气泡标签要动画弹出
- `CompareScreen`：筛选条件变了要刷新列表

---

## 3. 状态管理（数据怎么变）

**问题**：用户发一条新消息，聊天列表怎么更新？

**答案**：`setState()`

```dart
// 伪代码
setState(() {
  messages.add(newMessage);  // 改数据
});
// Flutter 会自动重新构建页面，显示新消息
```

**我们项目为什么不用 BLoC/Riverpod？**
- 项目规模小，用 `setState` 足够
- 减少学习成本，代码更直观
- 评委问"为什么不用状态管理库"，你可以说"项目规模适中，setState 更简单直接"

---

## 4. 相机怎么工作的？

**用到的插件**：`camera`

**流程**：
1. 申请相机权限（AndroidManifest.xml 配置）
2. 初始化相机控制器 `CameraController`
3. 显示相机预览画面 `CameraPreview`
4. 用户点击拍照 → `controller.takePicture()`
5. 拿到图片文件，传给后端

**拍照后怎么处理图片？**
- 转成 base64（二进制 → 字符串）
- 压缩到 600px 宽（减少传输体积）
- 通过 HTTP POST 发送给后端

---

## 5. 气泡标签怎么画的？（CustomPainter）

**问题**：Flutter 自带的组件里没有"带箭头的气泡标签"，怎么办？

**答案**：自己画！用 `CustomPainter`。

**CustomPainter 是什么？**
- 就像拿着画笔在画布上画画
- 你可以画圆形、矩形、三角形、线条
- 气泡标签 = 圆角矩形（身体）+ 三角形（箭头）

**项目中气泡标签的组成**：
- 深蓝黑圆角矩形（背景）
- 品牌青边框（1px）
- 序号圆点（品牌青底 + 白字）
- 商品名称文字

**答辩话术**：
> "气泡标签使用 Flutter 的 CustomPainter 自绘实现。主体是圆角矩形，箭头是三角形 Path，配合 Transform 实现位置偏移。所有样式参数（颜色、圆角、阴影）都抽离到 Design Token 中统一管理。"

---

## 6. 动画怎么实现的？

**气泡弹入动画**：
- 用 `AnimationController` 控制动画进度（0.0 → 1.0）
- `Curves.easeOutBack`：先快后慢 + 轻微回弹，看起来更优雅
- `AnimatedBuilder`：监听动画进度，每帧更新气泡的缩放和透明度

**锚点脉冲动画**：
- 气泡弹出时，对应锚点同步放大 + 变淡
- 用同一个 `AnimationController` 驱动，保证同步

---

## 7. 页面之间怎么跳转？

```dart
// 从首页跳转到结果页
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
);
```

**项目中的页面跳转**：
- 首页 → 相机页 → 结果页 → 比价页/聊天页/趋势页
- 多目标识别页 → 点击气泡 → 结果页

---

## 8. 自检问题

1. Widget 的两种类型是什么？（Stateless / Stateful）
2. 聊天页面为什么用 StatefulWidget？（消息列表会变化）
3. 相机拍照后图片怎么传给后端？（base64 + HTTP POST）
4. 气泡标签用什么画的？（CustomPainter 自绘）
5. 动画的缓动曲线是什么？（easeOutBack，轻微回弹）

**全部答对 → Day 2 通关 ✅**
