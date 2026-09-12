# 模块交付记录

每个小模块完成后：审阅实际差异，执行当前可行的针对性验证，提交并推送到已有 GitHub 远端。
每个大模块必须留下交付记录；未推送成功不得标记已上传，不使用强制推送。

## 当前进度

| 模块 | 状态 | 记录 |
| --- | --- | --- |
| 00 升级前代码整理 | 已完成清理与静态验证，运行时能力未验证 | [清理记录](00-cleanup.md) |
| Phase 1 基础链路 | 1A–1C 已完成离线工程验证与本地流式模型桩验证，真实模型／真机未验证 | [1A 记录](01a-recognition-foundation.md) · [1B 记录](01b-conversation-context.md) · [1C 记录](01c-streaming-protocol.md) |
| Phase 2 商品知识库 RAG | 2A 固定样例、2B字段混合检索与证据已验证；已接入4A可选购物会话；4D已统一旧比较／报告数据 | [2A 记录](02a-product-knowledge.md) · [2B 记录](02b-hybrid-retrieval.md) |
| Phase 3 结构化需求与排序 | 3A需求结构化、3B完整事实过滤／软偏好排序／逐条件证据已验证；4A可选购物聊天已接入，4B已接入Flutter | [3A 记录](03a-structured-requirements.md) · [3B记录](03b-evidence-ranking.md) |
| Phase 4 工作流与记忆 | 4A工作流、4B Flutter、4C明确偏好、4D样例统一、4E会话修复已完成对应工程验证；真机与远端存储不在已验收范围 | [4A](04a-shopping-workflow.md) · [4B](04b-flutter-shopping.md) · [4C](04c-preferences-memory.md) · [4D](04d-sample-unification.md) · [4E](04e-session-null-roundtrip.md) |
| Phase 5 评测与交付 | 80条冻结合成评测、旧基线重放、工程回归及隔离复现完成；最终33/40，未冒充目标达标 | [交付记录](05-evaluation-delivery.md) · [真实评测](../evaluation.md) · [验收手册](../acceptance.md) |

## 收尾增量

| 模块 | 状态 | 记录 |
| --- | --- | --- |
| 06A 语言解析与强度澄清 | 已完成Python／Dart工程回归和Flutter静态／bundle验证；非新独立质量评测，真实模型／真机仍未验收 | [06A记录](06a-language-clarification.md) |
| 06B 可读性整理与残留审计 | 代码整理及行为保持回归通过；本地残留文件的物理删除被执行策略拦截，未标记已删除 | [06B记录](06b-code-readability.md) |

## 每份记录必须包含

- 目的、实际范围和修改文件。
- 已实现行为，以及明确没有实现的部分。
- 实际执行的命令、结果和环境限制；不复制目标值作为实测结果。
- 已知风险、回退方式和唯一下一步。

## 验证材料边界

根据 2026-09-11 的最新要求，主仓库不保留测试文件或临时验证脚本。
这不代表测试没有价值，也不代表无需验证；运行、构建、静态检查仍需执行。
后续基线及评测材料应放在仓库外的独立验证目录，并记录版本、数据、命令和实际结果。
已建立本机仓库外工程检查目录 `D:\smart_price_ai-validation`；详情见 1A 交付记录。80条离线合成评测已建立，40开发／40最终及独立复现包均保留在仓库外；工程回归不能当作真实商品识别质量评测。

## Phase 4B 客户端

Flutter聊天现在显式进入购物工作流，支持确认编辑、证据展示、刷新／恢复会话、有据报告查看与导出。底层保持旧SSE兼容。实现与验证边界见 [4B记录](04b-flutter-shopping.md)。

## Phase 4C 长期偏好

已实现明确确认的本地SQLite偏好管理、工作流应用工具与Flutter管理页面。Redis/PostgreSQL完成接入评估但未实现远端适配，默认本地模式无外部服务依赖。详见 [4C记录](04c-preferences-memory.md)。

## Phase 4D 遗留样例统一

移除随机报价和伪造价格曲线；旧报告绑定目录证据，详见 [4D记录](04d-sample-unification.md)。

## Phase 4E 会话往返修复

开发集发现并修复显式未知参数被省略导致的多轮失败，见 [4E记录](04e-session-null-roundtrip.md)。

## Phase 5 评测与交付

见[Phase 5记录](05-evaluation-delivery.md)。345项Python工程回归不代表345个独立质量样本；80条合成评测的最终40条中33条通过，7个失败全部保留并归因。真实拍照／真机、远端存储和广泛自然语言理解仍有明确未完成或未验收边界。
