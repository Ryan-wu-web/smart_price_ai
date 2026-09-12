"""Conservative whole-clause parsing and explicit, non-destructive requirement edits.

No provider calls, product invention, storage writes or automatic relaxation.
Unknown wording remains blocking pending information instead of disappearing.
"""
from dataclasses import dataclass
import itertools
import json
import logging
import re

from pydantic import ValidationError

from app.core import requirements_config as cfg
from app.core.requirement_numbers import NUMBER_PATTERN, parse_number
from app.models.requirements import (
    ConditionInput, PendingCondition, RequirementCondition, RequirementConflict,
    RequirementParseRequest, RequirementParseResponse, RequirementSource, UserRequirements,
)

logger = logging.getLogger(__name__)
NUMBER = NUMBER_PATTERN
MONEY = rf"({NUMBER})(千|万)?(?:元|块钱|块)?"
# Do not split 1,000 into a valid but wrong budget=1; the whole clause stays pending.
CLAUSE_SEPARATOR = re.compile(r"[；;。\n！？!?]+|(?<![0-9０-９])[,，]|[,，](?![0-9０-９])")
AMBIGUOUS = re.compile(r"如果|或者|还是|左右|大概|大约|差不多|不是|不用|无需|不一定|不要求|取消|改成|改为|改到|换成|不再|但是|但|或者|或|并且|而是|不要.*不要|随便|都行|任何|无所谓")
LABELS = {"budget": "预算", "category": "品类", "brand": "品牌", "use_case": "用途", "feature": "功能", "parameter": "参数"}
QUESTIONS = {"intent": "希望推荐、对比、解释商品，还是生成报告？", "category": "想选什么品类？例如：推荐耳机。", "budget_max": "预算上限是多少元？例如：预算不超过500元。"}


class RequirementUpdateError(ValueError):
    def __init__(self, message: str, code: str = "REQUIREMENT_EDIT_INVALID"):
        super().__init__(message)
        self.code = code


def _condition(field, value, operator="eq", strength="hard", key=None, unit=None):
    return ConditionInput(field=field, value=value, operator=operator, strength=strength, key=key, unit=unit)


def _money(number, multiplier):
    return parse_number(number) * {None: 1, "千": 1000, "万": 10000}[multiplier]


def _signature(condition):
    return (condition.field, condition.key, condition.operator, condition.value, condition.strength, condition.unit)


@dataclass(frozen=True)
class StrengthClarification:
    """A parsed value whose filtering/ranking role still needs user confirmation."""
    options: list[ConditionInput]


def _with_strength(condition: ConditionInput, strength: str | None):
    if strength is not None:
        return None, [condition]
    return StrengthClarification([
        condition.model_copy(update={"strength": value}) for value in ("hard", "soft")
    ])


def _budget_conditions(text: str, strength: str | None = None):
    budget = re.fullmatch(rf"预算{MONEY}(?:到|至|[-~～]){MONEY}", text)
    if budget:
        lo, lm, hi, hm = budget.groups()
        if (lm is None) != (hm is None):
            return None  # Do not guess which end inherits a 千/万 multiplier.
        if (parse_number(lo) < 10 and _money(hi, hm) >= 100
                and any(char in lo + hi for char in "十百千万")):
            return None  # 三到五百 can imply an omitted 百; ask instead.
        return [_condition("budget", _money(lo, lm), "min", strength or "hard", unit="CNY"),
                      _condition("budget", _money(hi, hm), "max", strength or "hard", unit="CNY")]
    for pattern, operator in (
        (rf"(?:预算)?(?:不超过|最多|上限(?:为|是)?|至多){MONEY}", "max"),
        (rf"(?:预算)?(?:不少于|至少|下限(?:为|是)?){MONEY}", "min"),
        (rf"(?:预算)?(?:控制在)?{MONEY}(?:以内|以下)", "max"),
        (rf"(?:预算)?{MONEY}(?:以上)", "min"),
        (rf"预算(?:为|是)?{MONEY}", "max"),
    ):
        match = re.fullmatch(pattern, text)
        if match:
            return [_condition("budget", _money(*match.groups()), operator, strength or "hard", unit="CNY")]

    return None


def _clause(text: str):
    """Return (intent, conditions) only when the complete clause is understood."""
    text = re.sub(r"\s+", "", text)
    if AMBIGUOUS.search(text):
        return None
    text = re.sub(r"^(?:请|麻烦)(?:你)?", "", text)
    for command_intent, pattern in cfg.INTENT_PATTERNS.items():
        if re.fullmatch(pattern, text):
            return command_intent, []
    if text in cfg.INTENT_COMMANDS:
        return cfg.INTENT_COMMANDS[text], []
    intent = None
    for prefix in sorted(cfg.INTENT_PREFIXES, key=len, reverse=True):
        value = cfg.INTENT_PREFIXES[prefix]
        if text.startswith(prefix):
            intent, text = value, text[len(prefix):]
            break
    if intent is not None:
        text = re.sub(cfg.ACTION_FILLER, "", text, count=1)
    if text in cfg.CATEGORY_ALIASES:
        return intent, [_condition("category", cfg.CATEGORY_ALIASES[text])]
    for category in cfg.CATEGORY_ALIASES:
        if text.startswith(category):
            budget = _budget_conditions(text[len(category):])
            if budget is not None:
                return intent, [_condition("category", cfg.CATEGORY_ALIASES[category]), *budget]
    # An action with an unsupported object is pending as a whole, not partly accepted.
    if intent is not None:
        return None

    strength = None
    for prefix in cfg.SOFT_PREFIXES:
        if text.startswith(prefix):
            strength, text = "soft", text[len(prefix):]
            break
    if strength is None:
        for prefix in cfg.HARD_PREFIXES:
            if text.startswith(prefix):
                strength, text = "hard", text[len(prefix):]
                break

    budget = _budget_conditions(text, strength)
    if budget is not None:
        return None, budget

    # Only known feature phrases; unknown negations must not become positive features.
    if text in cfg.FEATURE_ALIASES:
        condition = _condition("feature", True, strength=strength or "soft", key=cfg.FEATURE_ALIASES[text])
        if condition.key in cfg.CLARIFY_FEATURE_KEYS:
            return _with_strength(condition, strength)
        return None, [condition]
    if text.startswith("不要") and text[2:] in cfg.FEATURE_ALIASES and strength is None:
        return None, [_condition("feature", False, key=cfg.FEATURE_ALIASES[text[2:]])]

    # Explicitly labeled string slots permit unknown brands, but not boolean expressions.
    negative = text.startswith("不要")
    body = text[2:] if negative else text
    match = re.fullmatch(r"品牌[:：]?([\w-]{1,80})", body)
    if match and not re.search(r"不|和|及|且|也|没|要", match[1]) and not (negative and strength is not None):
        return None, [_condition("brand", match[1], "ne" if negative else "eq", "hard" if negative else strength or "soft")]

    scenario = body[2:] if body.startswith("用于") else body
    if scenario in cfg.USE_CASES and not (negative and strength is not None):
        return None, [_condition("use_case", scenario, "ne" if negative else "eq", "hard" if negative else strength or "soft")]

    for label, (key, units) in cfg.PARAMETER_ALIASES.items():
        for operator_text, operator in (("不超过", "max"), ("不少于", "min"), ("至少", "min"), ("最多", "max"), ("等于", "eq")):
            match = re.fullmatch(rf"{label}{operator_text}({NUMBER})({'|'.join(map(re.escape, units))})", text)
            if match:
                value = parse_number(match[1]) * units[match[2]]
                return None, [_condition("parameter", value, operator, strength or "hard", key, cfg.NUMERIC_PARAMETERS[key][0])]
    laptop = re.fullmatch(rf"能放({NUMBER})(?:英寸|寸)电脑", text)
    if laptop:
        return None, [_condition("parameter", parse_number(laptop[1]), "min", strength or "hard", "laptop_inches", "inch")]
    for label, key in cfg.TEXT_ALIASES.items():
        match = re.fullmatch(rf"{label}[:：]?([\w-]{{1,80}})", body)
        if match and not re.search(r"不|和|及|且|也|没|要", match[1]) and not (negative and strength is not None):
            condition = _condition("parameter", match[1], "ne" if negative else "eq", "hard" if negative else strength or "soft", key)
            if not negative and key in cfg.CLARIFY_TEXT_KEYS:
                return _with_strength(condition, strength)
            return None, [condition]
    return None


def _conflicts(hard: list[RequirementCondition]) -> list[RequirementConflict]:
    conflicts = []

    def add(code, a, b, message):
        conflicts.append(RequirementConflict(
            code=code, condition_ids=[a.id, b.id], message=message,
            suggestion="请确认保留哪项条件，再通过明确编辑撤销另一项；当前未放宽或覆盖任何条件。",
        ))

    for a, b in itertools.combinations(hard, 2):
        if (a.field, a.key) != (b.field, b.key):
            continue
        label = a.key or LABELS[a.field]
        # Use cases are set membership; identity / individual parameters are scalar.
        if a.operator == b.operator == "eq" and a.value != b.value and a.field != "use_case":
            add("incompatible_values", a, b, f"{label}同时要求不同值：{a.value}与{b.value}。")
        elif {a.operator, b.operator} == {"eq", "ne"} and a.value == b.value:
            add("excluded_value", a, b, f"{label}既要求又排斥：{a.value}。")
        elif a.operator == "min" and b.operator == "max" and a.value > b.value:
            add("empty_numeric_range", a, b, f"{label}下限{a.value}高于上限{b.value}。")
        elif a.operator == "max" and b.operator == "min" and b.value > a.value:
            add("empty_numeric_range", a, b, f"{label}下限{b.value}高于上限{a.value}。")
        else:
            for exact, bound in ((a, b), (b, a)):
                if exact.operator == "eq" and ((bound.operator == "min" and exact.value < bound.value) or (bound.operator == "max" and exact.value > bound.value)):
                    add("empty_numeric_range", a, b, f"{label}指定值不在要求的范围内。")
    numeric_keys = sorted({(c.field, c.key or "") for c in hard if type(c.value) in (int, float)})
    for field, key in numeric_keys:
        group = [c for c in hard if (c.field, c.key or "") == (field, key)]
        lower = max((c for c in group if c.operator == "min"), key=lambda c: c.value, default=None)
        upper = min((c for c in group if c.operator == "max"), key=lambda c: c.value, default=None)
        if lower and upper and lower.value == upper.value and not any(c.operator == "eq" for c in group):
            excluded = next((c for c in group if c.operator == "ne" and c.value == lower.value), None)
            if excluded:
                conflicts.append(RequirementConflict(
                    code="excluded_value", condition_ids=[lower.id, upper.id, excluded.id],
                    message=f"{key or LABELS[field]}范围只允许{lower.value}，但该值同时被排斥。",
                    suggestion="请确认撤销范围或排斥条件；当前未自动放宽。",
                ))
    for category in hard:
        if category.field != "category" or category.operator != "eq":
            continue
        for parameter in hard:
            if parameter.field == "parameter" and parameter.key in cfg.NUMERIC_PARAMETERS and category.value in cfg.CATEGORY_ALIASES.values():
                if category.value not in cfg.NUMERIC_PARAMETERS[parameter.key][1]:
                    add("category_parameter_mismatch", category, parameter, f"样例库中{category.value}不适用参数{parameter.key}，请确认品类或参数。")
    return conflicts


class RequirementParser:
    def parse(self, request: RequirementParseRequest) -> RequirementParseResponse:
        # Revalidate direct service calls and detach caller-owned mutable state.
        request = RequirementParseRequest.model_validate(request.model_dump())
        state = request.previous.model_copy(deep=True) if request.previous else UserRequirements()
        if state.revision >= cfg.MAX_REVISION:
            raise RequirementUpdateError("需求记录已达轮次上限，请新建需求。", "REQUIREMENT_LIMIT")
        active = {c.id: c for c in state.conditions if c.removed_turn is None}
        pending = {p.id: p for p in state.pending if p.resolved_turn is None}
        if not set(request.remove_condition_ids) <= active.keys() or not set(request.resolve_pending_ids) <= pending.keys():
            raise RequirementUpdateError("待修改条件不存在或已处理，请刷新需求状态后重试。")
        turn = state.revision + 1
        for cid in request.remove_condition_ids:
            active[cid].removed_turn = turn
        for pid in request.resolve_pending_ids:
            pending[pid].resolved_turn = turn
        state.revision = turn

        def append_condition(value, source):
            for pending in state.pending:
                if (pending.reason == "strength_required" and pending.resolved_turn is None
                        and pending.source.turn < turn
                        and any(_signature(value) == _signature(option) for option in pending.options)):
                    pending.resolved_turn = turn
            sig = _signature(value)
            if any(_signature(c) == sig and c.removed_turn is None for c in state.conditions):
                return
            if len(state.conditions) >= cfg.MAX_ITEMS:
                raise RequirementUpdateError("需求记录已达容量上限，请新建需求；本次更新未应用。", "REQUIREMENT_LIMIT")
            state.conditions.append(RequirementCondition(
                **value.model_dump(), id=f"c{turn}-{len(state.conditions) + 1}", source=source,
            ))

        for raw_clause in CLAUSE_SEPARATOR.split(request.message):
            quote = raw_clause.strip()
            if not quote:
                continue
            # Long or unsupported clauses remain pending; no partial acceptance.
            if len(quote) > 500:
                raise RequirementUpdateError("单条需求过长，请用逗号分隔，每条不超过500字。", "REQUIREMENT_LIMIT")
            source = RequirementSource(kind="rule", turn=turn, quote=quote)
            try:
                parsed = _clause(quote)
            except (ValidationError, ValueError, OverflowError):
                parsed = None
            if parsed is None or isinstance(parsed, StrengthClarification):
                if len(state.pending) >= cfg.MAX_ITEMS:
                    raise RequirementUpdateError("待补充记录已达容量上限，请新建需求；本次更新未应用。", "REQUIREMENT_LIMIT")
                state.pending.append(PendingCondition(
                    id=f"p{turn}-{len(state.pending) + 1}", source=source,
                    reason="strength_required" if isinstance(parsed, StrengthClarification) else "unsupported_or_ambiguous",
                    options=parsed.options if isinstance(parsed, StrengthClarification) else [],
                ))
                continue
            intent, conditions = parsed
            if intent:
                state.intent, state.intent_source = intent, source
            for condition in conditions:
                append_condition(condition, source)
        for condition in request.additions:
            source = RequirementSource(kind="user_edit", turn=turn, quote=json.dumps(condition.model_dump(exclude_none=True), ensure_ascii=False, separators=(",", ":")))
            append_condition(condition, source)
        if request.intent is not None:
            state.intent = request.intent
            state.intent_source = None if request.intent == "unknown" else RequirementSource(kind="user_edit", turn=turn, quote=f"intent={request.intent}")
        if len(state.conditions) > cfg.MAX_ITEMS or len(state.pending) > cfg.MAX_ITEMS:
            raise RequirementUpdateError("需求记录已达容量上限，请新建需求；本次更新未应用。", "REQUIREMENT_LIMIT")
        response = self.analyze(state)
        logger.info("requirements_parsed revision=%d status=%s hard=%d soft=%d pending=%d conflicts=%d", turn, response.status, len(response.hard_constraints), len(response.soft_preferences), sum(p.resolved_turn is None for p in response.state.pending), len(response.conflicts))
        return response

    def analyze(self, state: UserRequirements) -> RequirementParseResponse:
        """Read-only assessment; do not invent a turn or alter client-carried history."""
        state = UserRequirements.model_validate(state.model_dump())
        warnings = []
        active_conditions = [c for c in state.conditions if c.removed_turn is None]
        hard = [c for c in active_conditions if c.strength == "hard"]
        soft = [c for c in active_conditions if c.strength == "soft"]
        conflicts = _conflicts(hard)
        present = {
            "intent": state.intent != "unknown",
            "category": any(c.field == "category" and c.operator == "eq" for c in hard),
            "budget_max": any(c.field == "budget" and c.operator == "max" for c in hard),
        }
        missing = [key for key in cfg.REQUIRED_SLOTS if not present[key]]
        unresolved = [p for p in state.pending if p.resolved_turn is None]
        questions = [QUESTIONS[key] for key in missing]
        for pending in unresolved:
            if pending.reason == "strength_required":
                questions.append(f"请确认“{pending.source.quote}”：是必须满足的硬条件，还是优先考虑的软偏好？请选择选项，或完整回复“必须{pending.source.quote}”／“最好{pending.source.quote}”。")
        if any(p.reason == "unsupported_or_ambiguous" for p in unresolved):
            questions.append("部分表达尚未理解或存在歧义，请逐条明确硬条件／软偏好；处理后显式确认对应待补充项。")
        if conflicts:
            questions.append("条件存在冲突，请确认需要撤销的条件；不会自动放宽。")
        if any(sum(c.field == field and c.key == key and c.operator == operator for c in hard) > 1 for field, key, operator in {(c.field, c.key, c.operator) for c in hard}):
            warnings.append("同一字段的硬条件按交集叠加，不采用最后一条覆盖；放宽前必须明确撤销旧条件。")
        if any((s.field, s.key) == (h.field, h.key) and ((h.operator == "ne" and s.value == h.value) or (h.operator == s.operator == "eq" and h.value != s.value)) for s in soft for h in hard):
            warnings.append("部分软偏好与硬约束不一致；硬约束优先，软偏好不能用于放宽条件。")
        warnings.append("本接口仅解析需求；ready只表示最小信息齐备，不代表存在满足条件的商品或已完成推荐。")
        response = RequirementParseResponse(
            state=state, status="conflict" if conflicts else "needs_clarification" if missing or unresolved else "ready",
            confirmed_condition_ids=[c.id for c in active_conditions], hard_constraints=hard, soft_preferences=soft,
            exclusions=[c for c in hard if c.operator == "ne" or (c.field == "feature" and c.value is False)],
            conflicts=conflicts, missing_information=missing, questions=questions, warnings=warnings,
        )
        return RequirementParseResponse.model_validate(response.model_dump())
