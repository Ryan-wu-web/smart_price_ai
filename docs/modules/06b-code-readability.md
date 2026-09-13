# 06B · 代码可读性整理与残留审计

日期：2026-09-12。基点：`ec373cb`。本模块在06A验证和推送之后进行，保持API、规则与排序行为，不扩大到依赖或存储迁移。

## 完成的整理

- `backend/app/services/requirements.py`：移除歧义正则中重复的“或者”分支；预算上下界缩写改为明确的token／multiplier命名；预算强度只计算一次；澄清函数改为表达真实职责的`_require_explicit_strength`，补充输入／返回类型和整句语义注释；复用条件签名，避免pending变量遮蔽，展开复杂条件，便于审核历史确认逻辑。
- `backend/app/models/requirements.py`：展开备选一致性检查，移除多余空行，不改变Schema。
- `backend/app/models/database.py`：删除4项无用导入（Integer、create_engine、sessionmaker、settings），明确标注旧ORM声明未接入当前运行链路。实际会话在sessions服务、明确偏好在preferences服务，不让旧声明冒充已实现的远端存储／历史价格能力。
- README及模块索引链接本记录。

## 测试与垃圾文件审计：没有夸大删除成果

`git ls-files`核验：主仓库受跟踪文件中没有test/tests测试目录、测试脚本、临时脚本、pyc/log/bak/tmp。工程验证仍全部在仓库外；Flutter平台debug/profile、图标、生成注册文件和正常mock样例并非垃圾，保留。

审查发现以下本地残留，**物理删除命令被执行策略拦截，未实际删除，也没有换工具绕过**：

| 路径／类型 | 数量与状态 |
| --- | --- |
| `backend/app/**/__pycache__/*.pyc` | 50个自动生成字节码，Git忽略，非生产源码 |
| `backend/tests`、`android-app/test`、`android-app/ios/RunnerTests`、`android-app/macos/RunnerTests`、`docs/test` | 5个空测试目录，无测试代码 |
| `backend/app/utils` | 1个空目录 |
| `backend/app/models/database.py` | 1个无运行时调用的旧ORM文件，文件删除未完成；仅清理无用导入并标注边界 |

引用检查及OpenAPI生成后`sys.modules`核验，旧ORM未被应用导入；没有动态导入／create_all调用。其4项声明仍可单独导入，但不执行建表。由于删除受阻，不把这个文件标成“已移除”。

不删除会话目录、SQLite、虚拟环境、依赖／构建缓存或必要平台文件；本机实际运行数据目录本次未发现文件，也没有清空其目录。保留有效常量LABELS——它用于冲突解释，并不是死代码。历史设计文档保留为历史，不按test/mock字样批量删除。

## 实际验证

材料在`D:\smart_price_ai-validation\cleanup`，主仓库不新增验证脚本。

- 清理前后281个规则快照（含口语、强度、金额、未知表达和多轮）JSON字节完全一致：SHA256 `ee7cc8a29bf77f90dad74869b0b1e5e0faf210a22d00a5aacf1c04023bb4d1f4`。这是行为保持检查，不是新质量评测。
- 清理后重新运行11套既有Python回归345项、新收尾37项、Dart payload到后端HTTP闭环2项：全部通过。具体退出码见`regression-summary.json`。
- 51个Python源文件AST通过；OpenAPI生成通过，旧ORM没有进入应用导入链；旧声明单独导入通过。
- 本模块未改Flutter。06A同一客户端代码的analyze无问题、bundle退出0，Dart 26/20/14项及识别上下文检查已通过；本模块不把“未再次运行Flutter”写成重新验证。
- `git diff --check`通过；未改变依赖或锁文件。
- Phase 5原ZIP SHA256仍为`f336857ea11cd203c78c942b62e72331c4497da6e12b2f33524ecf2489e98088`；原金标、原始结果和ZIP没有覆盖。

复跑快照（PowerShell，在仓库外生成结果）：

```powershell
$env:PYTHONIOENCODING='utf-8'
$env:PYTHONDONTWRITEBYTECODE='1'
& D:\smart_price_ai\backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\cleanup\parser_snapshot.py D:\smart_price_ai-validation\cleanup\recheck.json
Get-FileHash D:\smart_price_ai-validation\cleanup\recheck.json
```

## 限制、回退与唯一下一步

截至2026-09-12，本轮代码整理已经完成并验证，但物理删除仍受当时的执行策略限制。该限制已在下方2026-09-13收口中解除；清理始终限定于核验后的项目路径，没有批量删除依赖包中的tests或其他同名目录。

代码改动可按本模块提交单独回退，不需要迁移数据；06A的会话Schema回退限制仍适用。真实模型／真机／Docker仍需按[验收手册](../acceptance.md)执行，远端Redis／PostgreSQL适配没有实现；本轮不声称“全部Phase已验收”或“项目已无任何死代码”。

## 2026-09-13 本地垃圾清理收口

用户明确授权后，已物理删除此前受限的应用源码字节码缓存、6个空测试／工具目录，以及无运行时引用的`backend/app/models/database.py`。同时删除Flutter的`.dart_tool`、`build`、插件索引及各平台临时生成文件；这些内容均可由工具重新生成，不属于源码。Flutter验证期间重新生成的缓存已在验证完成后再次清理。

旧ORM删除后，默认后端不再需要未接入运行链路的`SQLAlchemy`、`psycopg2-binary`和`redis` Python包，已从`backend/requirements.txt`移除。Redis／PostgreSQL的Compose profile和配置占位仍保留为未来适配评估，不代表当前已经实现远端存储。`.venv`、业务源码、平台工程、样例商品库、会话目录和SQLite数据均未删除。

本次使用精确路径的Git清理命令，未执行全仓库通配删除。清理后重新核验应用导入、OpenAPI生成、Python语法、Flutter静态分析和Git差异；具体结果以本次执行输出为准。
