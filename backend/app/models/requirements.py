"""Strict, client-carried short-term requirements; never a trusted preference store."""
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.requirements_config import MAX_ITEMS, MAX_REVISION, NUMERIC_PARAMETERS, TEXT_PARAMETERS, FEATURE_ALIASES, PARSER_VERSION

Text = Annotated[str, Field(min_length=1, max_length=500, pattern=r"\S")]
ShortText = Annotated[str, Field(min_length=1, max_length=80, pattern=r"\S")]
ItemId = Annotated[str, Field(pattern=r"^[cp][1-9][0-9]{0,3}-[1-9][0-9]{0,2}$")]
Intent = Literal["unknown", "recommend", "compare", "explain", "report"]


class RequirementModel(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, str_strip_whitespace=True, allow_inf_nan=False)


class ConditionInput(RequirementModel):
    field: Literal["budget", "category", "brand", "use_case", "feature", "parameter"]
    operator: Literal["eq", "ne", "min", "max"]
    # Boolean must precede numbers: FastAPI/Pydantic response serialization otherwise
    # turns true/false into 1.0/0.0, breaking a subsequent strict-state request.
    value: ShortText | bool | int | float
    strength: Literal["hard", "soft"]
    key: ShortText | None = None
    unit: ShortText | None = None

    @model_validator(mode="after")
    def compatible_value(self):
        numeric = type(self.value) in (int, float)
        if self.field == "budget":
            if self.key is not None or self.unit != "CNY" or self.operator not in ("min", "max") or not numeric:
                raise ValueError("Budget requires min/max, numeric CNY and no key")
        elif self.field == "feature":
            if self.key not in FEATURE_ALIASES.values() or type(self.value) is not bool or self.operator != "eq" or self.unit is not None:
                raise ValueError("Feature requires a supported boolean key and eq")
        elif self.field == "parameter":
            if self.key in NUMERIC_PARAMETERS:
                if not numeric or self.unit != NUMERIC_PARAMETERS[self.key][0]:
                    raise ValueError("Numeric parameter requires a number and its canonical unit")
            elif self.key in TEXT_PARAMETERS:
                if type(self.value) is not str or self.operator not in ("eq", "ne") or self.unit is not None:
                    raise ValueError("Text parameter requires eq/ne string without unit")
            else:
                raise ValueError("Unsupported parameter key")
        elif type(self.value) is not str or self.operator not in ("eq", "ne") or self.key is not None or self.unit is not None:
            raise ValueError("Text slot requires eq/ne string without key or unit")
        if numeric and not 0 <= self.value <= 100_000_000:
            raise ValueError("Numeric requirement is outside supported range")
        if self.field == "category" and self.strength != "hard":
            raise ValueError("Category must be explicit hard scope")
        if self.operator == "ne" and self.strength != "hard":
            raise ValueError("Exclusions must be hard")
        return self


class RequirementSource(RequirementModel):
    kind: Literal["rule", "user_edit"]
    turn: int = Field(ge=1, le=MAX_REVISION)
    quote: Text


class RequirementCondition(ConditionInput):
    id: ItemId
    source: RequirementSource
    removed_turn: int | None = Field(default=None, ge=1, le=MAX_REVISION)


class PendingCondition(RequirementModel):
    id: ItemId
    source: RequirementSource
    reason: Literal["unsupported_or_ambiguous", "strength_required"] = "unsupported_or_ambiguous"
    # Alternatives only: neither enters conditions/ranking before explicit choice.
    options: list[ConditionInput] = Field(default_factory=list, max_length=2)
    resolved_turn: int | None = Field(default=None, ge=1, le=MAX_REVISION)


    @model_validator(mode="after")
    def consistent_options(self):
        if self.reason == "strength_required":
            if len(self.options) != 2 or {c.strength for c in self.options} != {"hard", "soft"}:
                raise ValueError("Strength clarification requires hard and soft alternatives")
            first, second = self.options
            if (first.field not in ("parameter", "feature") or first.operator != "eq"
                    or (first.field == "parameter" and first.key not in TEXT_PARAMETERS)
                    or first.model_dump(exclude={"strength"}) != second.model_dump(exclude={"strength"})):
                raise ValueError("Clarification alternatives must describe the same condition")
        elif self.options:
            raise ValueError("Unsupported wording must not invent clarification alternatives")
        return self


class UserRequirements(RequirementModel):
    schema_version: Literal[1] = 1
    revision: int = Field(default=0, ge=0, le=MAX_REVISION)
    intent: Intent = "unknown"
    intent_source: RequirementSource | None = None
    conditions: list[RequirementCondition] = Field(default_factory=list, max_length=MAX_ITEMS)
    pending: list[PendingCondition] = Field(default_factory=list, max_length=MAX_ITEMS)

    @model_validator(mode="after")
    def consistent_history(self):
        ids = [item.id for item in [*self.conditions, *self.pending]]
        if len(ids) != len(set(ids)):
            raise ValueError("Duplicate requirement ID")
        if (self.intent == "unknown") != (self.intent_source is None):
            raise ValueError("Intent and its source must agree")
        for item in [*self.conditions, *self.pending]:
            prefix = "c" if isinstance(item, RequirementCondition) else "p"
            if not item.id.startswith(f"{prefix}{item.source.turn}-"):
                raise ValueError("Requirement ID and source turn must agree")
            end = item.removed_turn if isinstance(item, RequirementCondition) else item.resolved_turn
            if item.source.turn > self.revision or (end is not None and not item.source.turn < end <= self.revision):
                raise ValueError("Invalid requirement history turn")
        if self.intent_source and self.intent_source.turn > self.revision:
            raise ValueError("Invalid intent source turn")
        return self


class RequirementParseRequest(RequirementModel):
    message: str = Field(default="", max_length=4000)
    previous: UserRequirements | None = None
    # Structured edits represent explicit user submissions, never inferred model output.
    additions: list[ConditionInput] = Field(default_factory=list, max_length=32)
    intent: Intent | None = None
    remove_condition_ids: list[ItemId] = Field(default_factory=list, max_length=MAX_ITEMS)
    resolve_pending_ids: list[ItemId] = Field(default_factory=list, max_length=MAX_ITEMS)
    confirm_changes: bool = False

    @model_validator(mode="after")
    def valid_edit(self):
        if not (self.message or self.additions or self.intent is not None or self.remove_condition_ids or self.resolve_pending_ids):
            raise ValueError("Provide a message or an explicit edit")
        if (self.remove_condition_ids or self.resolve_pending_ids) and not self.confirm_changes:
            raise ValueError("Removing or dismissing conditions requires explicit confirmation")
        for ids in (self.remove_condition_ids, self.resolve_pending_ids):
            if len(ids) != len(set(ids)):
                raise ValueError("Duplicate edit ID")
        return self


class RequirementConflict(RequirementModel):
    code: Literal["incompatible_values", "empty_numeric_range", "excluded_value", "category_parameter_mismatch"]
    condition_ids: list[ItemId] = Field(min_length=2)
    message: Text
    suggestion: Text


class RequirementParseResponse(RequirementModel):
    parser_version: Literal["requirements-rules-v1", "requirements-rules-v2"] = PARSER_VERSION
    mode: Literal["deterministic_rules"] = "deterministic_rules"
    state: UserRequirements
    status: Literal["ready", "needs_clarification", "conflict"]
    confirmed_condition_ids: list[ItemId]
    hard_constraints: list[RequirementCondition]
    soft_preferences: list[RequirementCondition]
    exclusions: list[RequirementCondition]
    conflicts: list[RequirementConflict]
    missing_information: list[str]
    questions: list[str]
    warnings: list[str]
