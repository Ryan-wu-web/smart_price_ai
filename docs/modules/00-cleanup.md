# 模块 00：升级前代码整理

日期：2026-09-11。基线提交：`362361429d350a4aa20a3f05cdf3eb489b1143eb`。

## 目的与边界

在 Phase 1 前移除用户不希望保留的测试材料及确认未使用的空包，修复相关构建引用。
保留 Flutter＋FastAPI、所有业务接口、页面和业务数据；本模块不修复识别、聊天或推荐算法。
“每个大模型留文档”按“每个大模块留交付记录”执行。

## 实际改动

| 文件／模块 | 操作与原因 |
| --- | --- |
| `backend/tests/` | 删除 14 个后端测试相关文件（含初始化和 fixture）；旧材料保留在基线及仓库外备份 |
| `android-app/test/` | 删除 2 个 Flutter 测试文件 |
| `android-app/ios/RunnerTests/`、`android-app/macos/RunnerTests/` | 删除 2 个原生模板测试文件 |
| 两个平台的 `Runner.xcodeproj/project.pbxproj` 与 `Runner.xcscheme` | 同步删除测试 target、专属构建对象和 scheme 引用，保留应用 target 与其构建设置 |
| `backend/Dockerfile` | 移除失效的 `COPY tests/ ./tests/` |
| `backend/requirements.txt` | 移除 pytest、pytest-asyncio 两个测试专用依赖 |
| `android-app/pubspec.yaml`、`pubspec.lock` | 移除 flutter_test，离线求解删除 11 个不再被引用的包；不升级现有业务依赖 |
| `backend/app/utils/__init__.py` | 删除没有代码且没有引用的空工具包初始化文件 |
| `docs/test/2025-06-05-full-test-plan.md` | 移除历史测试报告；其历史通过结论不作为当前验证依据 |
| 根 README、客户端 README、`docs/modules/` | 修复清理相关文档入口，替换 Flutter 模板说明，区分样例数据、目标和已验证事实 |

共删除 20 个已跟踪文件，其中 18 个为测试相关源码文件、1 个历史测试文档、1 个空包文件。
没有发现独立临时脚本，因此没有虚构额外脚本清理数量。
不删除 Docker、Gradle、平台工程、样例商品库和历史设计文档；它们不是仅凭名称就能认定的垃圾。
SQLAlchemy 模型尚未用于主链路，但与后续记忆持久化有关，本轮不擅自删除。

## 实际验证

环境：Windows、Python 3.12.13、Flutter 3.24.5、Dart 3.5.4。

| 验证 | 实际结果 |
| --- | --- |
| `flutter pub get --offline`（客户端目录） | 成功；复用本机缓存，移除 11 个仅供测试的依赖，没有新增或升级业务依赖 |
| `flutter analyze --no-pub`（客户端目录） | 通过：`No issues found!` |
| 对 `backend/app` 所有 Python 源文件逐一执行内存 `compile` | 28 个文件语法检查通过，不生成检查脚本或字节码文件 |
| iOS/macOS OpenStep 工程结构解析、对象引用及 scheme XML 检查 | 通过；分别移除 13／14 个测试专属对象，没有悬空 ID；保留对象中除项目／分组列表外的构建配置与基线相同 |
| 剩余 `backend/app`、`android-app/lib` 与基线内容比较 | 规范化 Git 换行后内容不变；没有改动业务实现 |
| Dockerfile 的 COPY 源路径检查 | 均存在；没有执行 Docker 镜像构建 |
| 备份 ZIP CRC 与删除文件内容核对 | 通过；20 个删除文件在规范化换行后均与 Git 基线一致 |
| 锁文件保留项逐项比较 | 仅移除 11 项；其余包定义完全不变 |
| README 相对链接、`git diff --check` | 通过 |
| 新增文本凭据模式检查 | 未发现匹配；启发式扫描不等于完整安全审计 |

临时内联检查中发现过 Xcode 清理顺序断言失败和 Windows 默认编码／换行比较问题；
修正操作顺序、显式 UTF-8 和 Git 换行归一化后重新检查通过，并非掩盖业务测试失败。

## 未验证与风险

- 未运行后端接口、真实模型或真机端到端；后端隔离依赖环境尚未建立，模型配置尚未验证。
- Windows 无法执行 Xcode 原生构建；结构检查不能替代 macOS 上的 iOS/macOS 构建。
- 删除测试降低仓库自包含的回归验证能力；后续必须在独立验证目录补足，而非以静态检查冒充业务通过。
- 原有缓存冲突、摘要上下文丢失、SSE 错误事件缺失、随机样例价格和静默放宽筛选等问题仍在。
- RAG、结构化需求、确定性排序、Agent State、长期偏好、80 条离线评测均尚未实现。

## 回退与基线保留

删除前创建了完整已跟踪版本的 ZIP，保存在仓库外，不上传 GitHub：
`D:\smart_price_ai-backups\before-cleanup-20260911-170115-3623614.zip`。
SHA256：`3D51EE2AFCAEEAAA85602AE06B7C35EDBBC28AE784A0D167F92A3C65B85A374F`。
这是本机备份，不是其他开发者必然可用的项目依赖；长期回退依据为上述 Git 基线。

恢复时优先将指定基线解压到一个新的空目录做比较，不覆盖已有工作区。
若需要回退清理提交，应先查看是否有后续用户修改，再通过正常反向提交处理，不使用 reset --hard 或强制推送。

## 唯一下一步

建立隔离的后端运行与仓库外验证环境，冻结升级前基线及评测定义，再开始 Phase 1 基础链路修复。
