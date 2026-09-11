"""Deterministic shopping orchestration over the existing parser and fact tools."""
import asyncio
from contextlib import suppress
import logging
import time

from app.core.requirements_config import CATEGORY_ALIASES
from app.models.recommendations import RecommendationRequest
from app.models.requirements import ConditionInput, RequirementParseRequest, UserRequirements
from app.models.schemas import ChatModelResult
from app.models.workflow import DecisionReport, NodeTrace, ShoppingInput, WorkflowError, WorkflowState
from app.services.recommendations import ProductRecommender
from app.services.requirements import RequirementParser, RequirementUpdateError
from app.services.sessions import SessionError

logger = logging.getLogger(__name__)
NODE_MESSAGES = {
    "intent": "正在识别购物意图", "requirements": "正在解析需求", "completeness": "正在检查信息完整度",
    "clarification": "需要补充信息或确认条件", "retrieval": "正在检索本地样例商品",
    "filtering": "正在执行硬条件过滤", "ranking": "正在计算偏好分项得分",
    "explanation": "正在生成带证据的解释", "report": "正在生成样例购物决策报告",
    "validation": "正在校验工作流与证据结构",
}
FOLLOWUPS = {"解释推荐": "explain", "为什么推荐": "explain", "对比候选": "compare", "比较候选": "compare"}
EDIT_MESSAGE = "应用已确认的条件调整"
RECOGNITION_MESSAGE = "确认识别品类"


def build_report(recommendation) -> DecisionReport:
    return DecisionReport(requirements_revision=recommendation.assessment.state.revision,
        catalog_sha256=recommendation.catalog.sha256, choices=recommendation.recommendations,
        limitations=[*recommendation.warnings, "排序仅基于已确认条件和当前样例库；未声明的参数不视为已满足。"])


def explain_result(state: WorkflowState) -> str:
    lines = [state.notice]
    if state.recognized_product and not state.recognition_confirmed:
        lines.append("识别结果只是观察信息，尚未确认；不会自动作为筛选条件或商品库中的同款。")
    if state.status == "unavailable":
        lines.extend(e.message for e in state.errors)
    elif state.status != "ready":
        if state.status == "no_candidates":
            lines.append("当前硬条件下没有可验证的候选，没有放宽任何条件。请查看不满足／未知条件并确认是否调整。")
        lines.extend(state.assessment.questions)
        if state.recommendation:
            lines.extend(q for q in state.recommendation.questions if q not in lines)
        if not state.assessment.questions and state.status == "needs_clarification":
            lines.append("请补充需求，例如：推荐耳机，预算500元。")
    else:
        rec = state.recommendation
        lines.append(f"已核对{rec.scoped_products}件同品类样例，{rec.eligible_products}件满足全部硬条件。")
        for row in rec.recommendations:
            p = row.product
            lines.append(f"{row.rank}. {p.brand} {p.model}：样例价格区间¥{p.price_range.min:g}–{p.price_range.max:g}；偏好得分{row.score:g}/100。证据：{p.evidence_id}。")
        if not any(row.components for row in rec.recommendations):
            lines.append("尚未设置软偏好，全部得分为0；按商品ID稳定排序，不代表质量优劣。")
        if state.requirements.intent == "compare":
            lines.append("对比对象为本轮候选；各商品参数、优缺点及条件检查见下方证据卡，不推断未记载差异。")
        elif state.requirements.intent == "explain":
            lines.append("推荐依据是逐条硬条件核验及配置权重的软偏好得分；满足、未满足和未知条件见证据卡。")
        if state.report:
            lines.append("决策报告已生成，复用本轮条件、目录快照和候选证据，不含实时报价或真实价格趋势。")
    return "\n".join(lines)


class ShoppingWorkflow:
    def __init__(self, catalog, retriever):
        self.catalog = catalog
        self.retriever = retriever

    async def run(self, message, session_id, session, options: ShoppingInput):
        previous = session.workflow
        requirements = previous.requirements if previous else UserRequirements()
        if options.expected_revision is not None and options.expected_revision != requirements.revision:
            raise SessionError("需求已更新，请刷新会话后再确认；本轮未修改条件。", "REQUIREMENT_REVISION_CONFLICT", 409)
        trace = []
        active_node = None
        started = time.monotonic()

        def status(node):
            nonlocal active_node, started
            now = time.monotonic()
            if active_node:
                trace.append(NodeTrace(node=active_node, elapsed_ms=round((now - started) * 1000, 3)))
            active_node, started = node, now
            logger.info("shopping_node node=%s revision=%d", node, requirements.revision)
            return {"node": node, "message": NODE_MESSAGES[node]}

        yield "status", status("intent")
        intent = options.intent
        parse_message = message
        if message.strip() in FOLLOWUPS:
            intent = intent or FOLLOWUPS[message.strip()]
            parse_message = ""
        if (options.remove_condition_ids or options.resolve_pending_ids or options.additions) and message == EDIT_MESSAGE:
            parse_message = ""
        recognized = session.current_product.model_dump(exclude_none=True) if session.current_product else None
        confirmed = bool(previous and previous.recognition_confirmed and previous.recognized_product == recognized)
        additions = list(options.additions)
        if options.confirm_recognition:
            category = recognized.get("category") if recognized else None
            if category not in CATEGORY_ALIASES:
                raise SessionError("识别品类不在样例库支持范围，请手动选择耳机、运动鞋或双肩包。", "RECOGNITION_CONFIRMATION_INVALID", 422)
            additions.append(ConditionInput(field="category", operator="eq", value=category, strength="hard"))
            confirmed = True
            if message == RECOGNITION_MESSAGE:
                parse_message = ""
                intent = intent or ("recommend" if requirements.intent == "unknown" else None)
        yield "status", status("requirements")
        try:
            assessment = RequirementParser().parse(RequirementParseRequest(
                message=parse_message, previous=requirements, additions=additions, intent=intent,
                remove_condition_ids=options.remove_condition_ids, resolve_pending_ids=options.resolve_pending_ids,
                confirm_changes=options.confirm_changes))
        except RequirementUpdateError as exc:
            raise SessionError(str(exc), exc.code, 422) from None
        requirements = assessment.state
        yield "status", status("completeness")
        data = dict(session_id=session_id, requirements=requirements, assessment=assessment,
                    recognized_product=recognized, recognition_confirmed=confirmed,
                    status=assessment.status, missing_information=assessment.missing_information)
        if assessment.status != "ready":
            yield "status", status("clarification")
        else:
            yield "status", status("retrieval")
            try:
                if self.catalog is None:
                    raise LookupError("catalog unavailable")
                # The worker only computes detached data; session writes stay on this task.
                # Queue callbacks are emitted at actual retrieval/filter/sort boundaries.
                loop = asyncio.get_running_loop()
                queue = asyncio.Queue()
                def notify(node):
                    if not loop.is_closed():
                        loop.call_soon_threadsafe(queue.put_nowait, node)
                async def compute():
                    try:
                        return await asyncio.to_thread(ProductRecommender(self.catalog, self.retriever).recommend,
                            RecommendationRequest(requirements=requirements, top_k=options.top_k),
                            allow_followup_intents=True, on_node=notify)
                    finally:
                        queue.put_nowait(None)
                task = asyncio.create_task(compute())
                try:
                    while (node := await queue.get()) is not None:
                        if node != active_node:
                            yield "status", status(node)
                    rec = await task
                finally:
                    if not task.done():
                        task.cancel()
                    with suppress(asyncio.CancelledError):
                        await task
                data.update(recommendation=rec, status=rec.status)
                yield "status", status("explanation")
                if requirements.intent == "report" and rec.recommendations:
                    yield "status", status("report")
                    data["report"] = build_report(rec)
            except (asyncio.CancelledError, GeneratorExit):
                raise
            except Exception as exc:
                logger.warning("shopping_tool_failed node=%s type=%s", active_node, type(exc).__name__)
                code = "CATALOG_UNAVAILABLE" if self.catalog is None else "SHOPPING_TOOL_UNAVAILABLE"
                error = WorkflowError(code=code, node=active_node,
                    message="本地商品知识暂时不可用，未生成或放宽推荐；已保留本轮明确需求，请稍后重试。")
                trace.append(NodeTrace(node=active_node, status="failed", elapsed_ms=round((time.monotonic() - started)*1000, 3)))
                active_node = None
                data.update(status="unavailable", recommendation=None, report=None, errors=[error])
        yield "status", status("validation")
        # Revalidation happens before any message or workflow snapshot is saved.
        trace.append(NodeTrace(node="validation", elapsed_ms=round((time.monotonic()-started)*1000, 3)))
        data["trace"] = trace
        state = WorkflowState.model_validate(data)
        result = ChatModelResult(reply=explain_result(state), action="none", action_data={"workflow": state.model_dump()})
        yield "workflow_result", (state, result)
