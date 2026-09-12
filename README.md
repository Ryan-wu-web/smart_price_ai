# Smart Price AI · AI 拍照识物与购物决策助手

保留 Flutter＋FastAPI，通过“识别上下文 → 结构化需求 → 商品知识检索 → 硬约束过滤 → 软偏好排序 → 有据解释 → 多轮追问 → 决策报告”帮助用户比较商品。

> **商品、参数和价格全部来自18条本地虚构样例，覆盖运动鞋、耳机、双肩包。** 不接真实电商、销量、评分或历史价格，不代表实时报价或真实商品性能。识别模型的输出也不自动成为知识库证据。

**2026-09-12交付状态：** Phase 1–4 的本地链路及 Phase 5 离线评测已实现并完成相应工程验证。真实模型／Flutter真机／Docker运行仍待验收；自然语言覆盖存在已公开的失败案例，不能把本版本称为通用购物Agent或生产就绪服务。

## 先看什么

- [早晨验收手册](docs/acceptance.md)：启动、逐项操作、预期结果和未验收项。
- [评测与复现](docs/evaluation.md)：80条数据、指标分子分母、基线、真实结果、7个失败案例。
- [语言解析与强度澄清收尾](docs/modules/06a-language-clarification.md)：v2变化、回归与兼容边界。
- [API](docs/api.md) · [当前架构](docs/architecture.md) · [每个模块做了什么](docs/modules/README.md)。

## 当前能力

| 能力 | 实际实现与边界 |
| --- | --- |
| 单／多目标识别 | 保留拍照、上传、气泡标注和识别结果编辑；精确缓存隔离、Pydantic校验、有限解析修复；需要有效模型配置，未实测真实识别质量 |
| 商品知识检索 | 固定JSON目录、字段切片、BM25＋字符TF-IDF稀疏向量、Metadata过滤、RRF融合和规则重排；不是语义Embedding模型 |
| 购物决策 | 确定性单工作流、需求确认、完整品类目录硬过滤、软偏好分项排序、证据与未满足条件；不是让LLM决定名次 |
| 多轮／流式 | 会话原文和摘要保留，购物状态持久化；SSE区分status/delta/result/error/end，未成功结束不提交临时结果 |
| Flutter | 复用聊天、识别和报告页面，增加节点状态、条件确认、证据和分数、恢复会话、明确偏好管理 |
| 记忆 | 当前会话为本地文件；长期偏好为SQLite，仅用户明确确认后保存／应用，可查看、修改、删除 |
| 旧接口 | 路径保留；compare使用固定目录，report按目录ID生成知识摘要；trend明确无历史数据，suggest为固定导航 |

## 本机快速启动（Windows PowerShell）

工作目录示例使用 `D:\smart_price_ai`。不要覆盖已有 `.env`，不要将密钥加入Git或聊天记录。

### 1. 后端：先验收不需要模型的购物链路

本轮实际使用 Python 3.12.13、仓库已有虚拟环境；依赖清单在 `backend/requirements.txt`。当前电脑可直接运行：

```powershell
Set-Location D:\smart_price_ai\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

**保持单worker、单实例，不加 `--workers`。** 从backend目录启动，避免会话／缓存路径改变。启动后打开 `http://127.0.0.1:8000/docs`；`/health`只说明进程可用，不保证模型或全部工具可用。

新电脑尚无环境时，以下为用户自行执行的安装步骤（本轮没有安装或升级依赖）：

```powershell
Set-Location D:\smart_price_ai\backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
# 仅首次且不存在.env时复制；本地购物可以保持模型配置为空。
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

模型配置缺失不影响知识接口、需求解析、推荐、长期偏好或显式shopping聊天；也不要求Redis／PostgreSQL运行。示例 `.env` 中的占位符不是可用凭据。

在Swagger执行 `POST /api/v1/chat`：

```json
{"message":"推荐耳机，预算500元，最好主动降噪","session_id":"morning-check-1","shopping":{}}
```

保留返回的session_id，在同会话继续发送“解释推荐”“对比候选”“生成报告”。购物结构位于 `action_data.workflow`，包含需求、版本、节点记录、候选、证据、分项与报告。若该会话已存在，请换一个新ID，避免验收时混入旧条件。

### 2. Flutter

当前API地址在 `android-app/lib/utils/constants.dart` 的 `apiBaseUrl`，它是本机旧局域网地址，**请先按实际运行设备修改**：

- Windows桌面与后端同机：`http://127.0.0.1:8000`。
- Android模拟器访问宿主：按模拟器网络配置使用宿主地址。
- 手机真机：改为电脑当前局域网IP，并让后端绑定该局域网IP；确保同一可信Wi-Fi。不要为了调试直接开放公网。

```powershell
Set-Location D:\smart_price_ai\android-app
C:\flutter\bin\flutter.bat run
```

新环境先自行运行 `flutter pub get`；本轮沿用已有依赖缓存，运行了 `flutter analyze --no-pub` 和 `flutter build bundle --no-pub`。bundle构建成功不代表APK安装、相机权限或真机网络已验证。

### 3. 真实拍照／旧模型聊天（单独验收）

仅这部分需要在本地 `backend/.env` 配置 `VOLCENGINE_API_KEY`、`VOLCENGINE_MODEL`，并确认 `VOLCENGINE_ENDPOINT` 对应支持图像和对话的服务。配置后重启；不得把 `.env` 或模型原始异常上传。接口、超时、有限修复参数见[API](docs/api.md)和 `backend/.env.example`。

拍照 → 编辑识别属性 → 进入聊天 → 确认识别品类 → 补充预算和条件。识别价格不是报价，识别型号不会自动映射成某个样例SKU；不能宣称已经找到了照片中商品的真实价格。

### 4. Docker（可选，尚未运行验证）

配置在 `backend/docker-compose.yml`。默认只启动api，端口绑定127.0.0.1，数据在local_data卷；本轮仅解析配置，没有下载镜像、构建或启动容器。

```powershell
Set-Location D:\smart_price_ai\backend
docker compose config --no-interpolate
docker compose up --build api
```

`optional-infra`中的Redis／PostgreSQL仅供后续接入评估；启用容器**不会**切换应用存储。DATABASE_URL／REDIS_URL不是已实现的存储开关。PostgreSQL密码需用户本地配置，不提供内置生产密码。

## 需求表达与安全边界

- 当前为有限规则语法，推荐用逗号分句。v2支持规范中文数字与部分口语，例如“请推荐耳机，控制在六百块以内”“能放十五点六寸电脑”；“三百五”“背包”及复杂未知表达仍追问。
- 品类和明确预算／数值界限用于硬过滤；一般品牌／用途未标强度时仍默认软偏好。功能／文本参数如“主动降噪”“颜色黑色”未标强度时先追问，不进入过滤排序。
- 在当前购物卡选择“必须满足”或“优先考虑”并确认；也可完整回复“必须颜色黑色”／“最好颜色黑色”。不同值不会自动处理旧待澄清项，旧已确认条件不会静默改变。详见[收尾记录](docs/modules/06a-language-clarification.md)。
- 硬条件冲突或无候选不自动放宽；确认撤销／修改后才重跑。未知参数不伪造，硬条件未知拒绝、软条件未知计0分。
- 长期偏好仅通过用户确认保存和应用，删除偏好不自动撤销会话已确认条件。当前没有用户账户鉴权，会话ID不是凭据。
- 会话／缓存位于从backend启动时的 `backend/data/`；偏好默认 `backend/data/preferences.sqlite3`。备份后再升级／回退，不要把新会话文件直接交给不认识新Schema的旧版本。

## 真实评测摘要

以下为冻结的v1历史结果：80条代理编写的合成样本，开发40、最终40，不是独立人工标注集。结果对应生产提交 `e4ea227`；冻结交付当时未根据最终集修改业务代码。之后v2针对已知失败补充解析和强度澄清，仅做工程回归，不覆盖旧结果，也不把曝光集重跑称为新的独立评测。完整定义见[评测文档](docs/evaluation.md)。

| 最终集指标 | 结果 |
| --- | --- |
| 意图识别 | 2/5（40%） |
| 槽位整句精确匹配 | 3/5（60%） |
| Recall@5（micro） | 7/7（100%） |
| 金标硬约束满足 | 9/12（75%） |
| 推荐有据 | 64/64（100%） |
| 结构化输出 | 40/40（100%，含符合预期的错误） |
| 购物工作流场景成功 | 23/25（92%，不含拍照／真机） |
| 全部子任务成功 | 33/40（82.5%） |

本地确定性购物SSE的10次首个非空文本延迟中位15.13ms、P95 31.00ms，**不是模型首字耗时**。旧版本没有可比较的新契约，基线质量指标为N/A，不声称“由0提升”。

按用户要求，主仓库不包含测试／临时脚本。复现数据、脚本、原始响应和日志独立保存在 `D:\smart_price_ai-validation`，本机ZIP交付位置见[评测文档](docs/evaluation.md)；只克隆GitHub源码不会获得该独立复现包。
