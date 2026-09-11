# Phase 4B：Flutter 有据购物工作流

日期：2026-09-12。范围：复用聊天／报告页面接入4A，不新增依赖。

## 做了什么

- 聊天发送显式 `shopping:{}`，后续携带当前需求版本；状态节点来自SSE，不伪造模型逐字输出。只有成功end后展示最终推荐。
- 新增 `ShoppingDecision` 客户端投影校验、`ShoppingDecisionCard`：样例声明、硬条件与软偏好、待澄清、冲突影响、参数、优缺点、分项、逐条件证据、节点耗时。
- 撤销条件、忽略未理解语句、确认识别品类都需要弹窗确认。历史快照只读；不会静默放宽条件。识别只确认品类，不宣称真实同款。
- 保留会话ID到已有SharedPreferences，进入空白聊天时GET恢复服务端最近20条消息与最新完整需求。刷新可恢复断流后已保存的状态；新建只移除本机恢复标记，不删服务端历史。不自动重发POST。
- 报告页复用经过核验的候选和目录SHA，导出需求版本、参数、分项、证据；不再调用第二次模型生成。旧报告入口保留，但删除本页虚构默认平台／价格／替代候选／购买时机。
- 旧SSE仍能被底层解码器读取；新购物页要求后端确实返回workflow，旧后端不会被误当成有据推荐。

## 文件

新增 `android-app/lib/models/shopping_decision.dart`、`android-app/lib/widgets/shopping_decision_card.dart`；修改 `android-app/lib/screens/chat_screen.dart`、`android-app/lib/screens/report_screen.dart`、`android-app/lib/services/api_service.dart`、`android-app/lib/services/chat_stream_decoder.dart`；同步README/API/架构。

## 验证（实际执行）

所有检查脚本、fixture、日志在主仓库外 `D:\smart_price_ai-validation`，未新增仓库测试或依赖。

- RED：旧解码器接受篡改硬约束；接入后相同检查拒绝。
- `C:\flutter\bin\dart.bat D:\smart_price_ai-validation\phase4b_checks.dart`：20/20，包括真实服务端两轮报告、硬条件遗漏／不满足、跨商品证据、错误报告版本／目录／候选、非法展示字段、跨会话和成功end边界。
- `phase1c_decoder_checks.dart`：26/26；`phase1b_recognition_check.dart`：通过。
- `phase4a_checks.py`：34/34。既有AnyIO TestClient资源警告仍可见，不声明无警告。
- Flutter工程内 `C:\flutter\bin\flutter.bat analyze --no-pub`：无问题（修复本轮8条lint）。
- `C:\flutter\bin\flutter.bat build bundle --no-pub`：exit 0。不是APK安装或真机交互验证。

## 手工验收

启动后端后进入聊天：推荐耳机 → 预算500元 → 最好主动降噪 → 展开证据 → 生成报告 → 分享。再加入预算100元观察不自动放宽，撤销预算需确认。退出重进，验证恢复。关闭后端时应友好失败，不展示未完成的新推荐。

## 限制与回退

本机无新增flutter_test依赖，所以没有Widget自动化或真机截图验证；分享／剪贴板平台插件、窄屏／无障碍布局需真机验收。纯Dart校验不是服务端Schema的安全替代。当前默认购物页是保守规则工作流，任意自然语言不保证理解；未理解语句明确阻止推荐。旧独立比价／趋势服务尚未统一，不能以本模块声称整个项目无随机Mock。恢复功能是本地单用户设计，不是鉴权。

可回退此模块代码到上一提交；保留服务端会话文件，不删除历史数据。
