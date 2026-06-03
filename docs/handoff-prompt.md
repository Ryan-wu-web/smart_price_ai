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

## 最新状态（2025-06-02）

### 6/2 完成：多目标识别彻底重写

**后端变更**：
- `backend/app/models/schemas.py` — `RecognizedObject` 从 `bbox` 改为 `center{x,y}`
- `backend/app/services/recognition.py` — `recognize_multiple()` Prompt 要求返回 `center`，新增 `_extract_center()` 兼容旧 `bbox` 回退
- 后端测试：26/26 PASS

**前端变更**：
- `android-app/lib/screens/multi_object_screen.dart` — **全删重写**
  - 加载态：`ScanLineOverlay`（扫描线 + 脉冲圆点），和拍照识物一致
  - 结果态：品牌青色气泡标签（序号 + 商品名）+ 三角箭头指向商品中心
  - 连接线：细渐变线连接气泡与锚点（只在有间距时显示）
  - 背景：Vignette 径向暗角（中心透明，边缘 25% 黑色）
  - 动画：`elasticOut` Spring 弹入 + 依次 stagger 120ms
  - 气泡样式：品牌青渐变（#00D4FF → #00B4D8）+ 16px 圆角 + 外发光阴影
- `flutter analyze` — 0 issues
- `flutter build apk --release` — 21.8MB

**真机验证**：功能可用，气泡标签正确指向怡宝瓶子和资生堂护肤品

### 6/4 待办：识别缓存修复 + AI 聊天优化 + 图片加载（6.3+6.4 叠加）

**6/3 遗留任务**：
- `backend/app/services/recognition.py` — 感知哈希缓存修复（dHash 替代 MD5，先压缩后计算 key）

**6/4 原定任务**：
- AI 聊天流式响应（后端 SSE + 前端打字机效果，降低 ~10s 感知等待）
- `ProductCard` 图片 `placehold.jp` → 本地占位图/国内稳定图床

### 6/5 待办：多目标识别 UI 美化

用户明确要求安排在 **6月5日**：
- 用 `frontend-design` skill 进一步美化气泡标签视觉
- 按 `docs/test/2025-06-05-full-test-plan.md` 进行全功能测试

### 已知活跃问题

| # | 问题 | 严重度 | 计划解决日期 |
|---|------|--------|------------|
| 1 | 识别缓存 MD5 对重新拍照无效 | P1 | **6/4**（6/3 合并）|
| 2 | AI 聊天速度 ~10s（LLM 物理限制）| P1 | 6/4 |
| 3 | 多目标识别 UI 需进一步美化 | P1 | 6/5 |
| 4 | ProductCard 图片 placehold.jp 国内仍可能不稳定 | P2 | 6/4 |

### 关键配置文件

```dart
// android-app/lib/utils/constants.dart
static const String apiBaseUrl = 'http://10.23.198.80:8000';
```

**注意**：IP 根据网络环境变化，切换网络后需更新并 `flutter clean && flutter run`。

### 启动命令

```powershell
# 后端（单独窗口保持运行）
cd C:\Users\Lenovo\Desktop\super_test\smart-price-ai\backend
uvicorn app.main:app --host 0.0.0.0 --port 8000

# 客户端
cd C:\Users\Lenovo\Desktop\super_test\smart-price-ai\android-app
flutter run
```

### 重要参考文档

- **测试流程**：`docs/test/2025-06-05-full-test-plan.md`
- **日期规划**：`docs/schedule.md`
- **设计规格**：`docs/superpowers/specs/2025-05-20-smart-price-ai-design.md`

---

**请基于以上上下文继续推进项目。**
