# Phase 4E：修复未知参数的会话往返

2026-09-12，Phase 5开发集暴露问题后追加的最小修复，未运行最终测试集。

## 原因与改动

运动鞋的防水等级、部分双肩包的电脑隔层尺寸等是明确的未知值null。SessionStore之前在写JSON时使用exclude_none，导致Pydantic要求存在但允许为null的value字段消失。首轮返回成功，下一轮却报SESSION_CORRUPT。耳机500元的旧回归没有覆盖这种参数组合。

只修改backend/app/services/sessions.py：保留null，并在原子写文件之前对序列化后的JSON再次Schema校验。未知不变成false或0；不放宽知识Schema，不清空历史。

## 验证

仓库外phase5_session_red.py真实复现五个waterproof_rating.value缺失及下一轮409；改后通过。phase5_session_checks.py两个检查通过，其中覆盖三个品类／六种预算、每种三轮（18次聊天），均可从磁盘恢复并生成报告；损坏文件仍保留。phase4a_checks.py 34/34回归通过。Python语法与git diff --check通过。

这是开发集驱动修复，不是最终集调参。评测保留修复前响应与结果，固定80条样本不改；最终集在修复后首次执行。

## 边界

历史上已经缺字段的文件不会自动补造或删除，仍明确报错并保留原文件；用户可新建会话。没有把不可信旧数据迁移为事实。已有AnyIO资源警告记录保留，未真机验证。

独立提交可正常revert。下一步：冻结修复后代码，完成80条评测的开发／最终结果及首文本实测。
