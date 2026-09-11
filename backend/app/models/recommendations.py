"""Evidence-backed, non-streaming recommendation contract; no inferred facts."""
from typing import Literal

from pydantic import Field, JsonValue, model_validator

from app.core.recommendation_config import ALGORITHM_VERSION
from app.models.knowledge import CatalogInfo, Identifier, ProductKnowledge
from app.models.requirements import ItemId, RequirementModel, RequirementParseResponse, UserRequirements
from app.models.retrieval import SearchResponse


class RecommendationRequest(RequirementModel):
    requirements: UserRequirements
    top_k: int = Field(default=5, ge=1, le=10)


class FactReference(RequirementModel):
    product_id: Identifier
    evidence_id: Identifier
    source_id: Identifier
    field: str
    locator: str = Field(pattern=r"^/products/[0-9]+/")
    value: JsonValue


class ConditionCheck(RequirementModel):
    condition_id: ItemId
    status: Literal["matched", "not_matched", "unknown"]
    reason: str
    evidence: list[FactReference] = Field(min_length=1)


class ScoreComponent(RequirementModel):
    dimension: str
    condition_ids: list[ItemId] = Field(min_length=1)
    unique_preferences: int = Field(ge=1)
    matched_preferences: int = Field(ge=0)
    unknown_preferences: int = Field(ge=0)
    weight: float = Field(gt=0)
    satisfaction: float = Field(ge=0, le=1)
    contribution: float = Field(ge=0, le=100)


class RankedProduct(RequirementModel):
    rank: int = Field(ge=1)
    product: ProductKnowledge
    score: float = Field(ge=0, le=100)
    components: list[ScoreComponent]
    hard_checks: list[ConditionCheck]
    soft_checks: list[ConditionCheck]
    reasons: list[str]
    satisfied_condition_ids: list[ItemId]
    unmet_condition_ids: list[ItemId]
    unknown_condition_ids: list[ItemId]

    @model_validator(mode="after")
    def grounded_qualification(self):
        if any(c.status != "matched" for c in self.hard_checks):
            raise ValueError("Ranked product must satisfy every hard condition")
        for check in [*self.hard_checks, *self.soft_checks]:
            if any((e.product_id, e.evidence_id, e.source_id) != (self.product.product_id, self.product.evidence_id, self.product.source_id) for e in check.evidence):
                raise ValueError("Condition evidence must belong to ranked product")
        return self


class RejectedProduct(RequirementModel):
    product_id: Identifier
    evidence_id: Identifier
    blockers: list[ConditionCheck] = Field(min_length=1)


class ConstraintImpact(RequirementModel):
    condition_id: ItemId
    not_matched_count: int = Field(ge=0)
    unknown_count: int = Field(ge=0)
    # Count within the existing category, not permission or a proposed new state.
    eligible_if_only_removed: int = Field(ge=0)


class RelaxationOption(RequirementModel):
    condition_id: ItemId
    eligible_if_only_removed: int = Field(ge=0)
    requires_confirmation: Literal[True] = True
    message: str


class RecommendationResponse(RequirementModel):
    algorithm_version: Literal["facts-ranking-v1"] = ALGORITHM_VERSION
    status: Literal["ready", "needs_clarification", "conflict", "unsupported_intent", "no_candidates"]
    assessment: RequirementParseResponse
    catalog: CatalogInfo
    policies: dict[str, str]
    weights: dict[str, float]
    retrieval_status: Literal["skipped", "ok", "empty", "unavailable"] = "skipped"
    retrieval: SearchResponse | None = None
    scoped_products: int = Field(default=0, ge=0)
    supplemented_products: int = Field(default=0, ge=0)
    eligible_products: int = Field(default=0, ge=0)
    recommendations: list[RankedProduct] = Field(default_factory=list)
    rejected_total: int = Field(default=0, ge=0)
    rejected: list[RejectedProduct] = Field(default_factory=list)
    constraint_impacts: list[ConstraintImpact] = Field(default_factory=list)
    relaxation_options: list[RelaxationOption] = Field(default_factory=list)
    empty_reason: Literal["no_category_match", "hard_constraints_not_met"] | None = None
    questions: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
