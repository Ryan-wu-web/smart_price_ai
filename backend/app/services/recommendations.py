"""Deterministic complete-fact filtering and preference ranking, without an LLM."""
import json
import logging
import math
from collections.abc import Callable
from collections import defaultdict

from app.core import recommendation_config as cfg
from app.models.knowledge import ProductKnowledge
from app.models.recommendations import (
    ConditionCheck, ConstraintImpact, FactReference, RankedProduct,
    RecommendationRequest, RecommendationResponse, RejectedProduct,
    RelaxationOption, ScoreComponent,
)
from app.models.requirements import RequirementCondition
from app.models.retrieval import SearchRequest
from app.services.knowledge import ProductCatalog
from app.services.requirements import RequirementParser
from app.services.retrieval import ProductRetriever

logger = logging.getLogger(__name__)


def _reference(product: ProductKnowledge, base: str, field: str, value) -> FactReference:
    return FactReference(product_id=product.product_id, evidence_id=product.evidence_id,
                         source_id=product.source_id, field=field,
                         locator=f"{base}/{field}", value=value)


def evaluate_condition(product: ProductKnowledge, base: str, condition: RequirementCondition) -> ConditionCheck:
    """Three-valued checks against complete facts, never retrieval text snippets.

    Lists of uses are not exhaustive negatives. Missing/unknown/wrongly typed
    facts cannot prove either a positive requirement or an exclusion.
    """
    c = condition
    known = True
    if c.field == "budget":
        value = product.price_range.model_dump()
        evidence = [_reference(product, base, "price_range", value)]
        matched = product.price_range.max <= c.value if c.operator == "max" else product.price_range.min >= c.value
        actual = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    elif c.field == "use_case":
        evidence = [_reference(product, base, "use_cases", product.use_cases),
                    _reference(product, base, "exclusions", product.exclusions)]
        supported = c.value in product.use_cases
        excluded = c.value in product.exclusions
        known = supported != excluded
        matched = supported if c.operator == "eq" else excluded
        actual = "精确用途声明" if known else "缺少唯一明确的支持／排斥声明"
    else:
        if c.field in ("feature", "parameter"):
            parameter = product.parameters.get(c.key)
            if parameter is None:
                # Cite the existing parameters object, not a fabricated missing pointer.
                evidence = [_reference(product, base, "parameters", {k: v.model_dump() for k, v in product.parameters.items()})]
                known, value = False, None
            else:
                evidence = [_reference(product, base, f"parameters/{c.key}", parameter.model_dump())]
                value = parameter.value
                known = value is not None and parameter.unit == c.unit
                if type(c.value) is bool:
                    known = known and type(value) is bool
                elif type(c.value) in (int, float):
                    known = known and type(value) in (int, float)
                else:
                    known = known and type(value) is str
        else:
            value = getattr(product, c.field)
            evidence = [_reference(product, base, c.field, value)]
        matched = False
        if known:
            if c.operator == "eq":
                matched = value == c.value
            elif c.operator == "ne":
                matched = value != c.value
            elif c.operator == "min":
                matched = value >= c.value
            else:
                matched = value <= c.value
        actual = json.dumps(value, ensure_ascii=False) if known else "缺失、未知或类型／单位不一致"
    status = "unknown" if not known else "matched" if matched else "not_matched"
    conclusion = {"matched": "满足", "not_matched": "不满足", "unknown": "知识不足，不能确认满足"}[status]
    label = c.key or c.field
    reason = f"{c.id}：{label} {c.operator} {json.dumps(c.value, ensure_ascii=False)} {c.unit or ''}；样例事实：{actual}；{conclusion}。"
    return ConditionCheck(condition_id=c.id, status=status, reason=reason, evidence=evidence)


def score_preferences(conditions: list[RequirementCondition], checks: list[ConditionCheck]) -> tuple[float, list[ScoreComponent]]:
    """Fixed per-dimension weights, exact duplicate preferences do not add weight."""
    groups = defaultdict(list)
    for condition, check in zip(conditions, checks, strict=True):
        groups[(condition.field, condition.key)].append((condition, check))
    total_weight = math.fsum(cfg.SOFT_WEIGHTS[field] for field, _ in groups)
    components = []
    for (field, key), pairs in sorted(groups.items(), key=lambda item: (item[0][0], item[0][1] or "")):
        unique = {}
        for c, check in pairs:
            # Numeric 5 and 5.0 are equivalent; booleans are a separate type.
            sig = (c.operator, "number" if type(c.value) in (int, float) else type(c.value).__name__, c.value, c.unit)
            unique.setdefault(sig, check)
        matched = sum(c.status == "matched" for c in unique.values())
        unknown = sum(c.status == "unknown" for c in unique.values())
        satisfaction = matched / len(unique)
        weight = cfg.SOFT_WEIGHTS[field]
        components.append(ScoreComponent(dimension=f"{field}:{key}" if key else field,
            condition_ids=[c.id for c, _ in pairs], unique_preferences=len(unique),
            matched_preferences=matched, unknown_preferences=unknown,
            weight=weight, satisfaction=satisfaction,
            contribution=100 * weight * satisfaction / total_weight))
    return round(math.fsum(c.contribution for c in components), cfg.SCORE_DECIMALS), components


class ProductRecommender:
    def __init__(self, catalog: ProductCatalog, retriever: ProductRetriever | None):
        self.catalog = catalog
        self.retriever = retriever

    def recommend(self, request: RecommendationRequest, *, allow_followup_intents: bool = False,
                  on_node: Callable[[str], None] | None = None) -> RecommendationResponse:
        notify = on_node or (lambda node: None)
        request = RecommendationRequest.model_validate(request.model_dump())
        assessment = RequirementParser().analyze(request.requirements)
        response = RecommendationResponse(status=assessment.status, assessment=assessment,
            catalog=self.catalog.info(), policies=dict(cfg.POLICIES), weights=dict(cfg.SOFT_WEIGHTS),
            questions=list(assessment.questions), warnings=list(cfg.WARNINGS))
        if assessment.status != "ready":
            return self._finish(response)
        if assessment.state.intent != "recommend" and not allow_followup_intents:
            response.status = "unsupported_intent"
            response.questions.append("本接口只处理商品推荐；对比、解释和报告请等待后续工作流接入，或明确切换为推荐意图。")
            return self._finish(response)

        notify("retrieval")
        hard, soft = assessment.hard_constraints, assessment.soft_preferences
        category = next(c.value for c in hard if c.field == "category" and c.operator == "eq")
        # Complete metadata scope, not top-K search hits. In this small local catalog,
        # this prevents false empties caused by relevance truncation or missing terms.
        products = sorted((p for p in self.catalog.iter_products() if p.category == category), key=lambda p: p.product_id)
        response.scoped_products = len(products)
        terms = [category]
        for c in [*hard, *soft]:
            if c.field in ("brand", "use_case") and c.operator == "eq":
                terms.append(str(c.value))
            elif c.field in ("feature", "parameter"):
                terms.append(c.key)
        query = " ".join(dict.fromkeys(terms))
        if len(query) > 240:
            response.warnings.append("检索查询已截至240字符；所有结构化条件仍逐条参与完整事实过滤与评分。")
        try:
            if self.retriever is None:
                raise ValueError("Index unavailable")
            retrieval = self.retriever.search(SearchRequest(query=query[:240], category=category, top_k=cfg.RETRIEVAL_TOP_K))
            if retrieval.catalog.sha256 != response.catalog.sha256:
                raise ValueError("Index snapshot mismatch")
            response.retrieval = retrieval
            response.retrieval_status = "ok" if retrieval.hits else "empty"
            if not retrieval.hits:
                response.warnings.append("混合检索未召回相关片段；已补齐同品类完整目录并逐条核对事实，空检索本身不代表无符合条件的商品。")
        except Exception as exc:
            logger.warning("recommendation_retrieval_failed type=%s", type(exc).__name__)
            response.retrieval_status = "unavailable"
            response.warnings.append("混合检索暂时不可用；已明确降级为同品类完整样例目录扫描，硬条件和证据检查没有放宽。")
        retrieved_ids = {hit.product_id for hit in response.retrieval.hits} if response.retrieval else set()
        response.supplemented_products = sum(p.product_id not in retrieved_ids for p in products)
        logger.info("recommendation_node node=retrieval status=%s scoped=%d supplemented=%d", response.retrieval_status, len(products), response.supplemented_products)

        notify("filtering")
        check_rows = []
        qualified = []
        ranked = []
        for product in products:
            source = self.catalog.get_evidence(product.evidence_id)
            if source is None:
                # Catalog invariants should prevent this; do not fabricate evidence.
                raise ValueError("Unresolved evidence")
            hard_checks = [evaluate_condition(product, source.locator, c) for c in hard]
            check_rows.append(hard_checks)
            blockers = [c for c in hard_checks if c.status != "matched"]
            if blockers:
                response.rejected_total += 1
                if len(response.rejected) < cfg.REJECTION_DETAIL_LIMIT:
                    response.rejected.append(RejectedProduct(product_id=product.product_id, evidence_id=product.evidence_id, blockers=blockers))
                continue
            qualified.append((product, source, hard_checks))

        notify("ranking")
        for product, source, hard_checks in qualified:
            soft_checks = [evaluate_condition(product, source.locator, c) for c in soft]
            score, components = score_preferences(soft, soft_checks)
            all_checks = [*hard_checks, *soft_checks]
            ranked.append(RankedProduct(rank=1, product=product, score=score, components=components,
                hard_checks=hard_checks, soft_checks=soft_checks,
                reasons=[c.reason for c in all_checks if c.status == "matched"],
                satisfied_condition_ids=[c.condition_id for c in all_checks if c.status == "matched"],
                unmet_condition_ids=[c.condition_id for c in all_checks if c.status == "not_matched"],
                unknown_condition_ids=[c.condition_id for c in all_checks if c.status == "unknown"]))

        for index, condition in enumerate(hard):
            impact = ConstraintImpact(condition_id=condition.id,
                not_matched_count=sum(row[index].status == "not_matched" for row in check_rows),
                unknown_count=sum(row[index].status == "unknown" for row in check_rows),
                eligible_if_only_removed=sum(all(c.status == "matched" for i, c in enumerate(row) if i != index) for row in check_rows))
            response.constraint_impacts.append(impact)
            if not ranked and (impact.not_matched_count or impact.unknown_count):
                response.relaxation_options.append(RelaxationOption(condition_id=condition.id,
                    eligible_if_only_removed=impact.eligible_if_only_removed,
                    message=f"可确认修改或撤销{condition.id}；仅移除此项在当前品类内有{impact.eligible_if_only_removed}条商品通过剩余硬条件（不代表可直接推荐，基础槽位仍需齐备）。未知事实也可先补充可靠知识。未自动执行任何修改。"))
        ranked.sort(key=lambda p: (-p.score, p.product.product_id))
        for rank, product in enumerate(ranked, start=1):
            product.rank = rank
        response.eligible_products = len(ranked)
        response.recommendations = ranked[:request.top_k]
        logger.info("recommendation_node node=filter_rank scoped=%d eligible=%d rejected=%d", len(products), len(ranked), response.rejected_total)
        if not ranked:
            response.status = "no_candidates"
            response.empty_reason = "no_category_match" if not products else "hard_constraints_not_met"
            response.questions.append("当前样例库没有该品类；请明确修改品类或补充可追溯样例知识，不会替换为其他品类。" if not products else
                "当前硬条件下没有可确认满足的样例商品。请查看逐项原因，通过需求解析接口明确确认修改；单项移除后仍为0时需要同时审视多项条件，不会静默放宽。")
        return self._finish(response)

    @staticmethod
    def _finish(response: RecommendationResponse) -> RecommendationResponse:
        validated = RecommendationResponse.model_validate(response.model_dump())
        logger.info("recommendation_node node=validate status=%s returned=%d", validated.status, len(validated.recommendations))
        return validated
