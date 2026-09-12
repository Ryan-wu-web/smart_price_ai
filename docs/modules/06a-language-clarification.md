# 06A · 语言解析与强度澄清收尾

日期：2026-09-12。基点：`c6e529c`。按用户要求先收尾再独立清理；没有增加依赖、安装工具、真实电商数据或模型调用。

## 目的与实际变化

Phase 5的v1失败显示：口语指令、中文预算和未明示的硬软边界容易丢失购物意图。本轮在既有确定性工作流内增量处理，不更换Flutter／FastAPI架构，也不把已曝光最终集改成全绿。

- 规则版本为`requirements-rules-v2`，接受有限完整指令：“请帮我比较两款耳机”“能解释一下这款商品为什么合适吗”“请帮我出一份购物报告”等。未知尾部仍整句追问。
- 规范中文整数／小数、全角数字与金额单位；支持“耳机控制在六百块以内”“能放十五点六寸电脑”。仅数值token转换，不改品牌型号和来源原句。“三百五”“一千二”“三到五百”、千分位等仍有歧义或未支持，不猜金额。
- 未注明强度的正向功能／文本参数返回`strength_required`及同值hard/soft两个options。它们不是已确认条件，暂不用于过滤排序；品牌／用途仍默认soft，明确预算／数值界限仍默认hard，负向排斥仍hard。
- 当前Flutter卡新增“必须满足”“优先考虑”，二次确认后用当前revision提交一条条件及对应pending处理。历史卡不可编辑。完整回复“必须颜色黑色”／“最好颜色黑色”可处理前一轮同值强度pending；不同值或普通未知pending不被自动移除。
- Schema验证备选一致性，保持旧v1响应和旧pending读取；不重写旧已确认条件。过期revision仍409，失败不污染存档。

## 文件

- `backend/app/core/requirement_numbers.py`：标准库数值token转换与中文规范写法检查。
- `backend/app/core/requirements_config.py`：版本、口语边界、参数单位和需澄清键配置。
- `backend/app/models/requirements.py`：pending原因、备选Schema与v1/v2兼容。
- `backend/app/services/requirements.py`：整句解析、预算转换、强度追问和明确确认。
- `android-app/lib/models/shopping_decision.dart`：备选校验、版本化确认payload。
- `android-app/lib/widgets/shopping_decision_card.dart`、`android-app/lib/screens/chat_screen.dart`：选择、确认与提交。
- README、API、架构、验收、评测版本边界和模块索引同步。

## 实际验证

所有材料位于`D:\smart_price_ai-validation\closure`，不加入主仓库。

| 检查 | 实际结果 |
| --- | --- |
| 新增Python收尾回归`closure_checks.py` | 37/37通过：解析、拒绝歧义、强度、旧状态、HTTP、SSE、报告、无候选与revision |
| 原Phase 1–5共11套Python回归 | 345项全部通过；套件有重叠，不是345个独立质量样本 |
| 新Dart澄清检查 | 14/14通过，包括错误备选拒绝和旧pending兼容 |
| Dart实产hard/soft JSON到后端HTTP闭环 | 2/2通过；首轮测试断言误把参数对象当值，改为读取value后通过，未改生产规则 |
| 原Dart SSE／购物决策 | 26/26、20/20通过；识别上下文检查通过 |
| `flutter analyze --no-pub` | No issues found |
| `flutter build bundle --no-pub` | exit 0；不等同APK、真机或触控验证 |
| `git diff --check` | 通过 |

主要复跑命令（PowerShell，不安装依赖）：

```powershell
$env:PYTHONIOENCODING='utf-8'
$env:PYTHONDONTWRITEBYTECODE='1'
& D:\smart_price_ai\backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\closure\closure_checks.py
& C:\flutter\bin\cache\dart-sdk\bin\dart.exe --enable-asserts D:\smart_price_ai-validation\closure\dart-clarification.dart
& D:\smart_price_ai\backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\closure\dart_backend_contract.py
Set-Location D:\smart_price_ai\android-app
& C:\flutter\bin\flutter.bat analyze --no-pub
& C:\flutter\bin\flutter.bat build bundle --no-pub
```

既有套件命令和退出码见外部`regression-summary.json`及各log。新增检查先在旧行为下暴露失败，再对改后版本回归。个别TestClient用例产生AnyIO资源警告，未把警告隐藏或当成功质量指标。

## 评测、限制与回退

- 原80条合成评测、最终33/40和ZIP不修改。v2已参考曝光失败，没有新的独立最终集；本轮数字仅工程回归，不代表自然语言准确率提升到100%。
- “背包”不自动等同双肩包；不扩展跑鞋、降噪等歧义语义。不是通用NLU，未声明的偏好仍需确认。
- 真模型拍照／LLM、Flutter真机触控、网络／权限、Docker仍未验收；Redis／PostgreSQL远端适配仍未实现，仅本地文件＋SQLite可用。
- 新版本读旧状态；旧版本不认识新`strength_required`。回退前停止服务并备份会话／SQLite，把v2新会话与旧版本隔离，不直接让旧后端覆盖新状态。不删除真实数据来让回退“成功”。

## 下一步

完成独立的确认无用残留清理及小范围可读性整理，再按验收手册进行真实模型／真机验收。
