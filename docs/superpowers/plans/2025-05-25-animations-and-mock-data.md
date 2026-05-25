# Day 5: 动效与交互 + Mock 数据扩充 — 实现计划

> **给代理工作者：** 必需子skill：使用 subagent-driven-development（推荐）或 executing-plans 逐个任务执行此计划。

**目标：** 为所有页面添加 iOS 风格的转场动画、加载状态、按压反馈、消息入场动画；搭建多目标识别页面骨架；扩充 Mock 数据到 200 条；添加黑色底部导航栏。

**架构：** 以 `constants.dart` Motion Token 为基础。使用 Flutter 原生动画实现。Mock 数据扩充在服务端进行。

**技术栈：** Flutter 3.24.5 + Dart 3.5.4 + Python/FastAPI

---

## 文件结构

```
android-app/lib/
├── utils/constants.dart           # 修改：新增 Motion Token
├── screens/home_screen.dart       # 修改：底部导航 + 扫描线加载
├── screens/result_screen.dart     # 修改：stagger + slide up
├── screens/compare_screen.dart    # 修改：Shimmer 骨架屏
├── screens/chat_screen.dart       # 修改：消息入场动画
├── screens/multi_object_screen.dart # 新建：多目标识别 + ripple
└── widgets/
    ├── bottom_nav_bar.dart        # 新建
    ├── scan_line_overlay.dart     # 新建
    ├── shimmer_card.dart          # 新建
    └── animated_chat_bubble.dart  # 新建

backend/app/services/comparison.py  # 修改：200+ 条 Mock 数据
```

---

## 批次 1: Motion Token + 底部导航栏

### 任务 1.1: `constants.dart` 新增 Motion Token

添加：`durationFast/Normal/Slow`、`easeSpring/Entrance/Exit/Bounce`、`staggerDelay`

### 任务 1.2: `bottom_nav_bar.dart` — 黑色底部导航栏

- 黑色背景 `#1A1A2E` + 顶部圆角 20px
- 4 个入口：首页/历史/聊天/我的
- 选中态：品牌青背景 `opacity 0.2` + 品牌青图标/文字 + 图标放大 1.15x（150ms 动画）
- 未选中态：白色 50% 透明度

### 任务 1.3: `home_screen.dart` 集成底部导航栏

在 Scaffold 底部添加 `BottomNavBar`，点击聊天图标跳转 `ChatScreen`

---

## 批次 2: 加载状态 + 页面转场

### 任务 2.1: `scan_line_overlay.dart` — 水平扫描线加载遮罩

- Stack：照片 + 暗化遮罩 `black.opacity(0.3)` + 扫描线 + 状态文字
- 扫描线：品牌青渐变 + 发光阴影，从左到右循环扫描（2s）
- 状态文字：白色粗体 + LinearProgressIndicator

### 任务 2.2: `home_screen.dart` 拍照加载状态

替换 `CircularProgressIndicator` 为 `ScanLineOverlay` 全屏遮罩

### 任务 2.3: `shimmer_card.dart` — Shimmer 骨架屏

- 模拟商品卡片布局（图片 + 平台标签/名称/价格占位条）
- ShaderMask + LinearGradient 实现 shimmer 流动效果（1.5s 循环）

### 任务 2.4: `compare_screen.dart` Shimmer 加载

`_isLoading` 时显示 3 个 `ShimmerCard`

---

## 批次 3: 结果页动效 + 聊天页动效

### 任务 3.1: `result_screen.dart`

- 属性标签：`AnimationController` + `Interval(index * 0.15, 1.0)` stagger 淡入（600ms）
- 建议卡片：`TweenAnimationBuilder` 从下方 50px 滑入 + `elasticOut` 弹性回弹（500ms）

### 任务 3.2: `animated_chat_bubble.dart`

- 用户消息：从右侧滑入 `Offset(30, 0)`
- AI 消息：从左侧滑入 `Offset(-30, 0)`
- `TweenAnimationBuilder` + `easeEntrance` + `Opacity`

### 任务 3.3: `chat_screen.dart` 发送按钮反馈

按压缩放 1.0 → 0.85（150ms），释放弹簧回弹

---

## 批次 4: 多目标识别页面

### 任务 4.1: `multi_object_screen.dart`

- 背景照片 + 3 个模拟检测框
- 检测框：品牌青边框 + 品牌青底色 + 商品名标签
- Ripple 展开动画：每个框延迟 `index * 0.25s`，从透明淡入（1.2s）
- 顶部提示：`检测到 N 个商品，点击识别`
- 点击跳转 ResultScreen

### 任务 4.2: `home_screen.dart` 添加入口

添加"多目标识别"快捷按钮

---

## 批次 5: Mock 数据扩充

### 任务 5.1: `comparison.py` 扩充到 200 条

- 4 大品类：鞋服 60 / 数码 50 / 美妆 50 / 家居 40
- 每个商品 3 个平台（淘宝/京东/拼多多）
- 添加 `image_url`（placeholder 格式）、`original_price`、丰富 `tags`

---

## 批次 6: 编译验证 + handoff

### 任务 6.1: 全局编译

- `flutter analyze` — 无 errors
- `flutter build apk --debug` — 成功

### 任务 6.2: 更新 `handoff-prompt.md`

---

## 执行选项

**计划完成。两种执行方式：**

**1. Subagent-Driven（推荐）** — 每批次分派子代理并行
**2. Inline Execution** — 在此会话中按批次顺序执行

**选择哪种方式？**
