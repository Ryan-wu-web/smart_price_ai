# Phase 4C：短期会话与明确确认的长期偏好

日期：2026-09-12。已交付本地单用户可运行方案；没有安装依赖、执行远端数据库迁移或部署。

## 实现

- 短期：继续复用4A的原子会话文件，保存最近消息、摘要游标、结构化需求和工作流。明确条件不依赖有损摘要。
- 长期：新增SQLite偏好档案，允许保存预算、品牌、用途及其明确排除条件，可指定仅适用于耳机／运动鞋／双肩包。功能和参数不作为本阶段稳定偏好自动保存。
- 新增GET/POST `/api/v1/preferences`，POST需严格布尔 `confirmed:true` 与 `expected_revision`；完整替换支持新增、修改、单条删除、清空。SQLite事务＋版本比较避免覆盖并发编辑，使用参数化SQL和及时关闭连接。
- 聊天与模型没有自动写偏好的路径。Flutter会话菜单提供管理页面，每次保存／修改／删除都明确确认。仅勾选并再次确认的偏好才导入本轮；已有硬条件保留，冲突照常追问。
- 读取偏好是独立工作流工具，增加preferences节点、偏好版本和ID来源记录。限定品类的偏好不能跨品类应用；请先确认本轮品类。偏好变化不会自动改写已保存的会话条件。
- 偏好损坏或不可写时返回友好503，不覆盖坏文件、不谎报保存成功；不应用偏好的购物链路仍可用。版本冲突409，客户端刷新后重新确认；POST不自动重发。

## Redis／PostgreSQL评估及取舍

当前事实：依赖清单已有redis、SQLAlchemy、psycopg2，但原主流程并未使用它们。此次不为了名词堆叠引入远端存储。

| 方案 | 适用角色 | 当前结论 |
| --- | --- | --- |
| 本地文件＋SQLite | 单用户开发、无需额外服务、可备份 | **已实现并验证**；文件会话仍要求单worker，SQLite是长期偏好唯一事实来源 |
| Redis | 将来带TTL的短期状态／缓存 | 当前仅完成设计评估与可选compose profile，**未实现Redis适配器**；不能把Redis丢失当成用户明确条件已撤销 |
| PostgreSQL | 将来多用户、跨实例一致性和审计 | 当前仅评估，**未实现PostgreSQL适配器或迁移**；需要先设计登录鉴权、用户隔离和迁移方案 |

为避免远端失效后出现两个偏好真相源，没有“远端失败就偷偷写SQLite”的运行时切库。当前明确选择本地模式；DATABASE_URL/REDIS_URL即使指向未启动服务也不会阻塞本地功能。未来远端模式须显式切换、迁移和校验，不得在重连后静默合并或覆盖偏好。

## 配置与启动

默认从backend启动：`uvicorn app.main:app --host 127.0.0.1 --port 8000`，不要添加多个workers。

- 偏好默认在 `backend/data/preferences.sqlite3`，可设置 `PREFERENCE_SQLITE_PATH`。
- 会话仍在启动工作目录 `data/sessions`。两类运行数据都不提交Git；数据库文件和会话文件一并备份。
- `backend/docker-compose.yml` 默认只启动api，取消对db/redis的强制depends_on，增加 `/app/data` 持久卷；默认端口绑定本机。
- Redis/PostgreSQL保留在 `optional-infra` profile，仅作为后续开发环境，不会切换应用存储。启用前用户需自行设置非空POSTGRES_PASSWORD；未运行该profile。
- 增加 `.dockerignore` 排除密钥、虚拟环境与运行数据，不更改现有密钥。

## API示例

GET偏好取得revision后，POST（示例确认文字，不含个人真实数据）：

```json
{"expected_revision":0,"confirmed":true,"items":[{"id":"headphone-budget","condition":{"field":"budget","operator":"max","value":500,"unit":"CNY","strength":"hard"},"category":"耳机","confirmation_text":"我确认常用耳机预算上限500元"}]}
```

先在会话确认耳机品类，再聊天发送：

```json
{"message":"应用已确认的长期偏好","session_id":"your-session","shopping":{"expected_revision":1,"preference_ids":["headphone-budget"],"preference_revision":1,"confirm_preferences":true}}
```

`preference_revision`是偏好版本，`expected_revision`是会话需求版本，不能混用。清空偏好使用相同POST结构、最新偏好版本、`items:[]`。这不会删除会话历史或自动移除当前会话已经确认的预算。

## 验证

材料均在 `D:\smart_price_ai-validation`，仓库无新增测试／临时脚本。

- RED：偏好API最初404。
- `phase4c_checks.py`：27/27。覆盖查看／保存／修改／删除、拒绝无确认／数字冒充布尔、重复ID、版本冲突、两个线程竞争只成功一次、损坏保留、不自动写／应用、明确应用、SSE节点、品类隔离、冲突不覆盖、偏好删除不改会话、远端URL不可达仍本地可用。
- `phase4a_checks.py`：34/34回归。AnyIO TestClient既有资源警告仍存在。
- Flutter analyze：无问题；bundle构建：exit0。未真机验证管理弹窗、持久化插件与应用跳转。
- Compose `config --no-interpolate --format json`解析通过；没有执行镜像下载、Docker构建／启动或外部服务验证。
- 后端源文件内存语法编译、git diff --check通过。

## 安全与回退

本地档案没有用户账号隔离；会话ID和偏好ID不是凭据。不要将当前服务开放到公网。SQLite文件、确认文字和会话属于本地用户数据，不输出到日志或上传Git。回退代码时保留SQLite和会话文件；含偏好来源字段的新workflow不能直接交给不认识这些字段的旧版本，先备份再选择升级兼容版本读取。
