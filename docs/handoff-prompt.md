# Smart Price AI - 上下文交接提示词

请将以下内容完整复制到新的 Kimi 对话框，作为项目上下文：

---

## 项目概述

**Smart Price AI** - AI 拍照识物与智能比价购物助手
- **客户端**：Flutter 3.24.5（Dart 3.5.4），真机调试（小米 25102RKBEC）
- **后端**：Python 3.13.9 + FastAPI + Uvicorn
- **AI**：火山引擎 Doubao-Seed-2.0-lite（EP ID: ep-20260514111211-cd94c）
- **项目路径**：`C:\Users\Lenovo\Desktop\super_test\smart-price-ai`
- **GitHub**：https://github.com/Ryan-wu-web/smart_price_ai.git

## 已完成（Day 1-3，5.21-5.22）

### Day 1 (5.21)
- 产品 brainstorm + 设计文档 + 实现计划
- 确定 3 个差异化亮点：多目标识别、AI 购物决策报告、多轮对话 AI 导购

### Day 2 (5.22)
- **后端**：7 个 API 路由 + 服务层 + 25 个测试用例全部通过
  - `/api/v1/recognize`（VLM+LLM 两阶段识物）
  - `/api/v1/suggest`（建议卡片）
  - `/api/v1/compare`（跨平台比价）
  - `/api/v1/filter`（自然语言筛选）
  - `/api/v1/trend/{id}`（价格走势）
  - `/api/v1/report`（决策报告）
  - `/api/v1/chat`（AI 导购对话）
- **客户端**：Flutter 4 个核心页面 + API 对接
- **环境**：Gradle 阿里云镜像、Android Studio JDK 17 配置、真机安装成功

### Day 3 (5.22 晚间)
- **代码审查**：审查了所有 7 个后端路由和所有客户端 API 调用
- **端到端测试**：拍照→识别→比价→AI 导购全链路跑通
- **修复 7 个 Bug**：
  1. recognize 请求字段 `image` → `image_base64`
  2. filter 请求字段 `query` → `query_text`
  3. RecognitionResult 模型缺少 `name`/`material`
  4. 结果页不显示商品名称
  5. 比价排序按钮不触发重新加载
  6. 比价品牌/颜色精确匹配失败（已改为宽松匹配）
  7. AI 导购未传递 `current_product` 导致 LLM 不知道上下文

## 当前状态（5.22 晚间）

- ✅ 后端服务可正常启动（`uvicorn app.main:app --host 0.0.0.0 --port 8000`）
- ✅ 真机 App 可正常安装运行
- ✅ 拍照识物→识别结果→比价→AI 导购全链路可用
- ⚠️ API_BASE_URL 需根据网络环境调整（当前为热点模式 IP）
- ⚠️ Mock 数据仅约 20 条，计划 Day 7-8 扩充到 200+
- ⚠️ UI 为"骨架"级别，尚未美化

## 接下来计划（按修正后的 schedule.md）

| 日期 | 阶段 | 内容 |
|------|------|------|
| **Day 4 (5.23)** | UI 精细打磨 | 视觉落地：渐变/纹理/字体层级/卡片阴影/品牌一致性 |
| **Day 5 (5.24)** | UI 精细打磨 | 动效与交互：转场动画/磁吸效果/加载状态/空状态插画 |
| **Day 6 (5.25)** | UI 精细打磨 | 响应式适配 + 打磨收尾 |
| **Day 7-8 (5.26-27)** | 功能完善 | 建议卡片 API 对接、决策报告、价格走势、Mock 数据扩充、LLM Fallback |
| **Day 9-10 (5.28-29)** | AI Pipeline 调优 | VLM/NL 筛选 Prompt 调优、多轮对话优化 |
| **Day 11-13 (5.30-6.1)** | 测试与优化 | 全量测试、性能优化、边缘 case |
| **Day 14-16 (6.2-6.4)** | 文档与演示 | README、API 文档、AI 使用总结、Demo 视频 |
| **Day 17-20 (6.5-6.8)** | 缓冲与交付 | 最终 QA、材料打包、提交 |

## 关键配置文件

### 后端环境变量（`backend/.env`）
```
VOLCENGINE_API_KEY=ark-4126af52-1fda-4c17-8561-8db89e066502-95563
VOLCENGINE_ENDPOINT=https://ark.cn-beijing.volces.com/api/v3/chat/completions
```

### 客户端 API 地址（`android-app/lib/utils/constants.dart`）
```dart
static const String apiBaseUrl = 'http://<电脑IP>:8000';
// 注意：根据网络环境（WiFi/热点）更换 IP，const 值必须 flutter clean + flutter run 才能生效
```

### Gradle 配置
- `android-app/android/settings.gradle` - 阿里云 Maven 镜像
- `android-app/android/build.gradle` - 阿里云镜像 + subprojects compileSdk 覆盖
- `android-app/android/app/build.gradle` - compileSdk = flutter.compileSdkVersion
- `android-app/android/gradle.properties` - `org.gradle.java.home=C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot`

## 启动命令

```powershell
# 后端（单独窗口保持运行）
cd C:\Users\Lenovo\Desktop\super_test\smart-price-ai\backend
uvicorn app.main:app --host 0.0.0.0 --port 8000

# 客户端
cd C:\Users\Lenovo\Desktop\super_test\smart-price-ai\android-app
flutter run
```

## 设计文档参考

- **设计规格**：`docs/superpowers/specs/2025-05-20-smart-price-ai-design.md` §5 UI/UX 设计方向
- **实现计划**：`docs/superpowers/plans/2025-05-20-smart-price-ai.md`
- **日期规划**：`docs/schedule.md`

## 已知注意事项

1. **网络切换**：手机和电脑必须在同一网络（建议手机开热点，电脑连热点），关闭翻墙梯子
2. **IP 更换**：切换网络后需在 `constants.dart` 中更新 IP，并执行 `flutter clean && flutter run`
3. **后端重启**：修改 Python 代码后必须重启 uvicorn 才能生效
4. **image_picker 降级**：pubspec.yaml 中 `image_picker: ^0.8.9`（因 flutter_plugin_android_lifecycle 兼容性问题）

---

## Day 4 (5.23) 更新 — UI 精细打磨完成

### 新增页面（3个）
- `screens/splash_screen.dart` — Aurora 炫彩渐变启动页，粗体标题 "SMART PRICE AI"，脉冲按钮，stagger 淡入动画，支持 prefers-reduced-motion
- `screens/trend_screen.dart` — 价格趋势页骨架（商品信息卡片 + 走势图占位 + AI分析 + 价格统计）
- `screens/report_screen.dart` — 决策报告页骨架（渐变头部 + 最优选择卡片 + 其他选择 + AI建议 + 保存按钮）

### Design Token 体系重构
- `utils/constants.dart` — 完整 Token 体系：
  - **颜色**：brandColor `#00B4D8`、primaryDark `#0077B6`、accentColor `#FF6B6B`、background `#F8F9FA`
  - **字体层级**：display(28px)/h1(22px)/h2(17px)/body(14px)/caption(12px)/label(13px)
  - **圆角**：8/12/16/20 四级体系
  - **阴影**：shadowCard/shadowElevated/shadowButton/shadowLight 四级
  - **间距**：8px 基准网格
  - **渐变**：brandGradient、auroraGradient、placeholderGradient

### 全局打磨
- `main.dart` — 完整 ThemeData（AppBar/Card/Button/InputDecoration），SplashScreen 为入口，全局 NoiseTexture 噪点纹理
- `widgets/bottom_input_bar.dart` — 浅色主题重构（白底 + 品牌渐变圆形发送按钮）

### 页面打磨（4个现有页面）
- `home_screen.dart` — display 字体层级、品牌渐变拍照按钮、搜索框阴影、最近识别卡片阴影、白色底部栏
- `result_screen.dart` — 图片区域阴影、属性标签无边框+品牌青底色、建议卡片跳转 TrendScreen、AI建议左侧装饰线
- `compare_screen.dart` — 筛选标签选中态改为品牌青背景
- `chat_screen.dart` — 浅色底部栏、跳动圆点 AI 思考指示器、决策报告跳转 ReportScreen

### 组件打磨（3个组件）
- `widgets/product_card.dart` — 卡片阴影、促销红价格色、平台标签优化
- `widgets/suggestion_card.dart` — 统一 shadowCard、图标容器圆角统一
- `widgets/chat_bubble.dart` — 圆角 18→16 优化、统一 shadowLight

### QA 补充（frontend-design）
- `widgets/noise_texture.dart` — 极淡噪点纹理覆盖层（opacity 0.03），避免纯平色单调感
- `splash_screen.dart` — `MediaQuery.disableAnimations` 检测，减少动画偏好用户自动跳过动画

### 构建验证
- `flutter analyze` — 无 errors，无 warnings
- `flutter build apk --debug` — ✅ 成功（161.2s）

### Git 提交记录
```
5d9f7b2 a11y(batch6): add NoiseTexture overlay + prefers-reduced-motion support
ea06a62 feat(batch2+3): SplashScreen+Aurora gradient, TrendScreen, ReportScreen + polish screens
0c203d8 design(batch4): polish ProductCard/SuggestionCard/ChatBubble
d3add63 design(batch1): complete Design Token system, theme config, light BottomInputBar
```

---

---

## Day 5 (5.25) 更新 — 动效与交互 + Mock 数据扩充

### Motion Token 体系（constants.dart）
- `durationFast` (150ms) / `durationNormal` (300ms) / `durationSlow` (500ms)
- `easeSpring` (elasticOut) / `easeEntrance` (easeOutCubic) / `easeExit` (easeInCubic) / `easeBounce` (bounceOut)
- `staggerDelayFast` (80ms) — 错开动画延迟基准

### 新增组件（4个）
- `widgets/bottom_nav_bar.dart` — 黑色背景 + 品牌青选中态 + 顶部指示条滑动动画（TweenAnimationBuilder），4 tab（首页/搜索/聊天/我的），高度 64 + 安全区，圆角 20
- `widgets/scan_line_overlay.dart` — 全屏扫描线加载遮罩，AnimatedBuilder 驱动水平扫描（2s 循环），品牌青渐变发光 + 暗化遮罩 0.7，3 段状态文字循环切换，底部线性进度条
- `widgets/shimmer_card.dart` — 骨架屏商品卡片，ShaderMask + LinearGradient shimmer 流动（1.5s 循环），模拟图片/标签/名称/价格占位
- `widgets/animated_chat_bubble.dart` — 消息入场动画，用户从右侧滑入（Offset 0.3→0），AI 从左侧滑入（Offset -0.3→0），300ms easeEntrance

### 页面动效（4个页面）
- `home_screen.dart` — 拍照加载替换为 ScanLineOverlay（showGeneralDialog），新增「多目标识别」快捷入口卡片（拍照按钮下方），集成 BottomNavBar（替换旧白色底部栏）
- `compare_screen.dart` — 加载状态替换为 3 个 ShimmerCard 骨架屏
- `result_screen.dart` — 4 个属性标签 stagger 淡入（Interval 0.0/0.15/0.3/0.45 → 1.0），4 个建议卡片从下方 50px 滑入 + elasticOut 弹性回弹（500ms），SingleTickerProviderStateMixin
- `chat_screen.dart` — ChatBubble 替换为 AnimatedChatBubble

### 多目标识别页面（差异化亮点）
- `screens/multi_object_screen.dart` — TickerProviderStateMixin + ripple 展开动画，3 个模拟检测框（左上白鞋/右上黑包/中间手机），点击弹出 BottomSheet 商品详情，从 HomeScreen 入口进入

### Mock 数据扩充
- `backend/app/services/comparison.py` — 从 ~20 条扩充到 **300 条**
- 4 大品类：运动鞋(Nike/Adidas) 60 / 数码(Apple/小米) 75 / 美妆(雅诗兰黛/兰蔻) 90 / 家居(无印良品/IKEA) 75
- 每品牌 3 款 × 3 平台(mock_jd/mock_taobao/mock_pdd)
- 图片 URL：`https://via.placeholder.com/300x300/00B4D8/FFFFFF?text=...`
- 价格策略：京东基准，淘宝 0.95-1.1 倍，拼多多 0.85-0.95 倍
- 评分 4.5-5.0，标签（自营/官方/包邮/百亿补贴/假一赔十）
- 划线价 = 价格 × 1.1-1.3

### 静态分析修复
- 修复 `use_build_context_synchronously`（HomeScreen 异步后加 mounted 检查）
- 修复 7 处 `prefer_const_constructors`（report_screen / trend_screen）
- 移除 test/widget_test.dart 未使用 import

### 构建验证
- `flutter analyze` — ✅ 0 issues（无 errors，无 warnings，无 infos）
- `flutter build apk --debug` — ✅ 成功（35.3s）

### Git 提交记录
```
495eb8f data(batch5): expand mock products to 200+ with images and realistic prices
9a4a7df feat(batch2+3): ScanLineOverlay, ShimmerCard, AnimatedChatBubble, result screen animations
a204c26 feat(batch4): MultiObjectScreen with ripple detection boxes + home entry
b496920 feat(batch1): Motion Tokens + BottomNavBar integrated into HomeScreen
```

---

---

## Day 6 (5.27) 更新 — 响应式适配 + 边缘 Case + 无障碍 + 后端异常中间件

### 响应式适配
- 新增 `widgets/responsive_layout.dart` — `ResponsiveLayout` 工具类，3 档断点（small<360 / medium 360-420 / large>420）
- `widgets/suggestion_card.dart` — 固定宽度 140px → 三档自适应（130/150/170）
- `widgets/product_card.dart` — 图片固定 100x100 → `screenWidth * 0.22`（clamp 80-120）
- `widgets/shimmer_card.dart` — 骨架图片尺寸同步 ProductCard
- `screens/home_screen.dart` — 最近识别卡片宽度自适应（120/140/160），拍照按钮 padding 自适应（20/28/36）
- `screens/result_screen.dart` — 图片高度 `screenHeight * 0.25`（clamp 180-280），建议列表高度三档（130/140/150）
- `screens/compare_screen.dart` — 筛选标签大屏（>420）自动换行（Wrap），小屏保持横向滚动
- `screens/trend_screen.dart` — 走势图高度 `screenHeight * 0.28`（clamp 180-300）
- `screens/splash_screen.dart` — 横屏时 Spacer flex 减少（3/4 → 1/2）
- `screens/chat_screen.dart` — 决策卡片最大宽度限制 600px + Center

### 边缘 Case
- 新增 `utils/network_checker.dart` — `connectivity_plus` 网络预检
- 新增 `utils/error_messages.dart` — 统一错误文案（timeout/serverError/noInternet/cameraDenied）
- `services/api_service.dart` — 所有 7 个接口请求前检查网络，无网络直接抛异常不上传请求
- `screens/home_screen.dart` — 捕获 `PlatformException`（camera_access_denied），弹窗引导用户

### 无障碍
- `widgets/bottom_nav_bar.dart` — 4 个 tab 添加 `Semantics(label, button, selected)`
- `screens/result_screen.dart` — 属性编辑弹窗关闭后焦点返回
- `screens/home_screen.dart` — 图片来源弹窗关闭后焦点返回

### 后端全局异常中间件
- 新增 `backend/app/middleware/error_handler.py` — 统一捕获未处理异常，返回结构化 JSON：`{"detail": "...", "code": "INTERNAL_ERROR", "path": "..."}`
- `backend/app/main.py` — 注册 `app.add_exception_handler(Exception, global_exception_handler)`

### 构建验证
- `flutter analyze` — ✅ 0 issues
- `flutter build apk --debug` — ✅ 成功（52.6s）
- `pytest backend/tests/` — ✅ 25/25 PASS

### Git 提交记录
```
4b3a984 feat(day6-backend): register global exception handler in FastAPI
0e44273 a11y(day6): return focus after image source dialog closes
becb242 feat(day6): ApiService network pre-check + unified ErrorMessages
7b7bc5f feat(day6-responsive): CompareScreen Wrap filter + TrendScreen chart height + SplashScreen landscape + ChatScreen maxWidth
7a9d1c6 feat(day6): ResultScreen responsive image/list height + focus management
99a78b6 feat(day6): HomeScreen responsive cards/button + camera permission handling
60a5c84 feat(day6-responsive): SuggestionCard adaptive width via ResponsiveLayout
7aaf527 feat(day6-responsive): ProductCard image size relative to screen width
0c0f6e9 feat(day6-responsive): ShimmerCard image size sync with ProductCard
6fefc53 a11y(day6): add Semantics labels to BottomNavBar tabs
4368a41 feat(day6-infra): add NetworkChecker with connectivity_plus
aa26adc feat(day6-infra): add ErrorMessages utility for unified error copy
7ab3e83 feat(day6-infra): add ResponsiveLayout utility with 3 breakpoints
```

---

---

## Day 7 (5.28) 更新 — 功能补全 I

### 后端修复
- `backend/app/services/comparison.py` — 新增 `CATEGORY_GROUPS` 映射（"数码"→["手机","耳机",...]），修复分类过滤时大品类无法匹配到子品类商品的问题
- `backend/tests/` — 分类映射测试 5/5 PASS

### 扫描线美化（批次2 + 修复）
- `widgets/scan_line_overlay.dart` — 删除 `LinearProgressIndicator`，改为 **3 个品牌青脉冲圆点**（呼吸动画：scale + opacity + 发光阴影）
- 删除"AI 正在识别..."等多段状态文字，避免遮挡照片
- 圆点尺寸 14×14，最小不透明度 0.5，带 BoxShadow 发光效果
- 扫描线位置下调至 0.65 屏幕高，圆点位于 0.72 屏幕高

### AI 图标更换
- `screens/chat_screen.dart` AppBar — `Icons.smart_toy` → `Icons.auto_awesome`

### ResultScreen 建议卡片真实 API（批次3）
- 「官方旗舰店」— 调用 `ApiService().getSuggestions()` + 筛选 tags 含"自营"/"官方" → 跳转 CompareScreen（带品牌筛选）
- 「相似推荐」— 调用 `ApiService().getSuggestions()` 传入 category → 跳转 CompareScreen
- 修复 `use_build_context_synchronously`（6 处 info）

### 新增页面（批次4）
- `screens/search_screen.dart` — 搜索页：顶部搜索栏（自动聚焦）+ 热门标签 + 搜索结果列表（ProductCard）+ 空态/错误态/无结果态，点击结果跳转 CompareScreen
- `screens/history_screen.dart` — 历史页：SharedPreferences 读取 `recent_records`，列表展示（图片+分类+品牌+时间），点击弹出 **Dialog 详情**（图片/分类/品牌/颜色/置信度/时间 + "查看比价"按钮），支持清空确认
- `screens/profile_screen.dart` — 我的页：头像上传（相册选择）/修改、昵称编辑弹窗、识别次数统计、设置菜单（关于/清除缓存）

### AI 气泡排版优化
- `widgets/chat_bubble.dart` — 重写为 Row 布局：AI 消息左侧增加**品牌青渐变圆圈头像**（`auto_awesome` 图标 + 阴影），用户消息右侧增加默认灰色头像，气泡阴影加深（blurRadius 12）

### 导航连接
- `screens/home_screen.dart` — 搜索框跳转 SearchScreen、底部导航 1→HistoryScreen、3→ProfileScreen，保存记录时 `scan_count++`

### 构建验证
- `flutter analyze` — ✅ 0 issues
- `flutter build apk --release` — ✅ 成功（21.5MB）

### Git 提交记录
```
918e394 fix: 删除 ScanLineOverlay 已移除的 statusText 参数调用
2a8699c fix: 扫描线圆点加大+加深+删除文字，优化视觉
87d3ffe feat: Day 7 搜索页/历史页/我的页 + AI 气泡头像优化
11121be feat: ResultScreen 建议卡片接入真实 API + 官方旗舰店/相似推荐
448fb77 feat(day7): scan line pulse dots + AI icon auto_awesome
a57e64c fix(day7): add category_groups mapping to fix category filter
```

---

## Day 8 (5.29) 计划 — 功能补全 II

### 目标
基于 Day 7 真机测试反馈继续优化，并完成剩余核心功能。

### 待完成任务
1. **价格走势图真实数据** — `screens/trend_screen.dart` 接入 `getTrend` API + 折线图库（fl_chart）
2. **决策报告真实数据** — `screens/report_screen.dart` 接入 `generateReport` API
3. **分享功能** — 商品比价结果分享卡片（截图/文本）
4. **真机测试反馈修复** — 根据用户测试反馈逐项修复
5. **Mock 数据继续扩充** — 覆盖更多边缘品类

### 设计原则
- 保持现有 Design Token 风格一致
- 复用已有组件
- 每个功能完成后编译检查 + 提交

---

**请基于以上上下文继续推进项目。**
