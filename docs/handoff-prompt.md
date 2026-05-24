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

**请基于以上上下文继续推进项目。当前下一步是 Day 5 (5.25) 的动效与交互：**
- 页面转场动画（Hero 动画 / 自定义路由）
- 卡片磁吸悬浮效果
- 加载状态 Skeleton
- 空状态插画
- 图片预览过渡
