# Phase 4A：服务端有据购物决策工作流

## 目的与范围

在现有聊天接口中接通 Phase 3 的真实检索、过滤、排序和证据，保留识别与旧模型聊天。基线提交 `42aa069d53c220f0187df6c4d71b26a020c99fdd` 已成功正常推送并核验远端 SHA。本模块没有引入依赖、数据迁移或真实电商接入。

修改文件：`backend/app/models/workflow.py`、`backend/app/services/workflow.py`（新增）；`models/schemas.py`、`services/sessions.py`、`services/chat.py`、`services/recommendations.py`、`core/streaming.py`、`routers/chat.py`，以及 README、API、架构和模块索引。

## 已实现行为

- `/chat` 和 `/chat/stream` 增加可选 `shopping: {}`。新会话显式开启；已有购物会话即使后续省略该字段仍走购物链路。没有购物状态的旧请求继续使用原模型聊天，不改变 URL、reply/action/action_data 或 SSE v1 framing。
- 单工作流节点：意图、需求、完整度、追问、检索、过滤、排序、解释、报告、结构校验。检索、过滤、软评分各自在真实执行边界发送状态，记录节点完成／失败及耗时。不是多 Agent，也不是模型自行排序。
- 工作流通过现有规则解析器和事实推荐器完成；不需要模型密钥。规则不理解的句子仍记为 pending 并阻止推荐，不宣称支持任意自然语言。
- Session v2 增加可选工作流快照，保留旧消息和摘要，不把有损摘要作为结构化约束。每次仅在完整结果校验后将消息与工作流原子保存。旧 list/v2 会话可继续读；无批量迁移。单进程锁，不支持多 worker 共享写入。
- `WorkflowState` 包含会话 ID、结构化需求、完整度、识别观察与确认标记、含检索证据的推荐、候选分项、报告、节点轨迹、错误和实际重试数。当前确定性工具不盲重试，`retries=0`。
- 图片商品仅作为观察；`confirm_recognition=true` 只确认支持的品类，不把识别品牌、价格或参数变成硬条件或真实同款。品类变化不自动撤销原条件。
- 撤销条件、消除 pending 必须 `confirm_changes=true` 并提供 `expected_revision`。过期状态返回409，原文件不变。新增预算仍是交集，不代替原预算。
- 支持固定追问“解释推荐”“为什么推荐”“对比候选”“比较候选”“生成报告”。重新按当前条件核验目录；报告直接复用本轮排序、完整商品证据和目录 SHA，不经过第二次模型生成。对比范围是本轮候选，不支持任意指定两款真实商品。
- `GET /api/v1/chat/sessions/{session_id}` 返回购物快照、商品观察、旧摘要和最近20条消息，供本地恢复及冲突处理；不存在返回404。仅适合现有无登录本地单用户场景，session ID 不是生产身份认证。
- 目录不可用、工具异常输出安全降级结果，保留本轮明确需求；不会继续使用上一轮陈旧推荐。索引异常复用3B明确目录扫描回退。模型流超时／JSON失败仍沿用1C处理。购物超时、取消、保存失败不提交未完成回合；SSE error/end 不伪造成功。
- 证据输出限制为450KB，超限在保存前拒绝，兼容现有 Flutter 单帧上限。仅发送确定性结果文本一次 delta，不伪装为模型逐 token 流；节点状态可提前显示。

## 实际验证

验证材料都在主仓库外 `D:\smart_price_ai-validation`。

```powershell
Set-Location D:\smart_price_ai
$env:PYTHONIOENCODING='utf-8'
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase4a_checks.py
& backend\.venv\Scripts\python.exe D:\smart_price_ai-validation\phase4a_socket_checks.py
```

- RED：`phase4a_red_checks.py` 升级前1项失败（仍调用禁止使用的模型，HTTP500）；升级后同项通过。首轮成功检查生成的临时会话已移到外部验证目录，后续使用独立临时目录。
- 本模块34/34：非流／SSE、预算跨轮、报告证据、追问、未知句子、无候选、不静默放宽、显式撤销、revision冲突、识别确认、目录／索引／工具失败、旧会话、隔离、Schema、取消／超时／保存失败、并发编辑。
- 回归：3B 55/55、3A 53/53、2B 32/32、2A 31/31、Phase1 32/32、1B 29/29、1C 35/35。记录在 `phase4a-regressions.json` 及对应日志。本轮执行外围目录枚举触发命令60秒超时，但以上7个 Python 子进程均已结束且记录 exit_code=0，不把整个外围命令记为成功。
- 后端47个源码文件内存 compile，通过；`git diff --check` 通过。
- 真实 localhost Uvicorn、独立 cwd、无密钥／Redis／PostgreSQL：6个流程通过，包括多轮预算、偏好、报告、过期编辑和13事件的SSE；进程已停止。单次确定性首文本约0.017秒仅为工程冒烟采样，**不是模型TTFT或产品性能指标**。详见 `phase4a-socket-results.json`。
- TestClient 检查出现 AnyIO 内存流 ResourceWarning；断言通过不代表没有警告。未为消除警告升级依赖；实际网络路径另行验证。真实模型、Flutter真机、Docker、多进程负载未验证。前端接入属于下一模块。

## 风险、回退和下一步

**已完成并验证**：本地确定性购物服务端闭环及旧模块回归。
**尚未完成**：Flutter新卡片／条件编辑、长期偏好及Redis/PostgreSQL方案、旧随机Mock链路统一、80条独立产品评测与完整端到端验收。新购物模式不调用旧无证据报告，但旧路由仍存在，不能说所有旧业务已迁移。

回退应正常反向提交，不强推；老版本 SessionState 不接受新增 workflow 字段，回退前应备份新购物会话并保留当前版本读取或另启会话目录，不删除用户历史。本次未执行回退。

**唯一下一步：Phase 4B——复用 Flutter 聊天页，显式发送 shopping，展示节点、需求确认／撤销、证据与分项及有据报告，不再从该页调用旧无证据报告。**
