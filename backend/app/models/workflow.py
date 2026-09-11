"""Typed, local shopping workflow. No unconfirmed recognition or model preferences."""
from typing import Literal

from pydantic import Field, JsonValue, model_validator

from app.models.knowledge import SAMPLE_NOTICE
from app.models.recommendations import RecommendationResponse, RankedProduct
from app.models.requirements import ConditionInput, Intent, ItemId, RequirementModel, RequirementParseResponse, UserRequirements

WorkflowNode = Literal["intent", "requirements", "completeness", "clarification", "retrieval", "filtering", "ranking", "explanation", "report", "validation"]


class ShoppingInput(RequirementModel):
    top_k: int = Field(default=5, ge=1, le=10)
    expected_revision: int | None = Field(default=None, ge=0, le=1000)
    additions: list[ConditionInput] = Field(default_factory=list, max_length=32)
    intent: Intent | None = None
    remove_condition_ids: list[ItemId] = Field(default_factory=list, max_length=128)
    resolve_pending_ids: list[ItemId] = Field(default_factory=list, max_length=128)
    confirm_changes: bool = False
    confirm_recognition: bool = False

    @model_validator(mode="after")
    def explicit_edits(self):
        if self.remove_condition_ids or self.resolve_pending_ids:
            if not self.confirm_changes or self.expected_revision is None:
                raise ValueError("Removing conditions requires confirmation and current revision")
        return self


class NodeTrace(RequirementModel):
    node: WorkflowNode
    status: Literal["completed", "failed"] = "completed"
    elapsed_ms: float = Field(ge=0)


class WorkflowError(RequirementModel):
    code: str
    node: WorkflowNode
    message: str


class DecisionReport(RequirementModel):
    title: str = "样例商品购物决策报告"
    notice: Literal[SAMPLE_NOTICE] = SAMPLE_NOTICE
    requirements_revision: int = Field(ge=1)
    catalog_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    # Same fact-checked ranked products, not a second model-authored selection.
    choices: list[RankedProduct] = Field(min_length=1, max_length=10)
    limitations: list[str]


class WorkflowState(RequirementModel):
    version: Literal[1] = 1
    session_id: str = Field(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
    requirements: UserRequirements
    assessment: RequirementParseResponse
    status: Literal["ready", "needs_clarification", "conflict", "no_candidates", "unavailable"]
    recognized_product: dict[str, JsonValue] | None = None
    recognition_confirmed: bool = False
    recommendation: RecommendationResponse | None = None
    report: DecisionReport | None = None
    missing_information: list[str] = Field(default_factory=list)
    trace: list[NodeTrace] = Field(default_factory=list, max_length=30)
    errors: list[WorkflowError] = Field(default_factory=list, max_length=10)
    retries: int = Field(default=0, ge=0, le=2)
    notice: Literal[SAMPLE_NOTICE] = SAMPLE_NOTICE

    @model_validator(mode="after")
    def consistent_result(self):
        if self.requirements != self.assessment.state:
            raise ValueError("Assessment must describe persisted requirements")
        if self.status == "ready" and (self.recommendation is None or not self.recommendation.recommendations):
            raise ValueError("Ready requires grounded candidates")
        if self.recommendation is not None and self.recommendation.assessment.state != self.requirements:
            raise ValueError("Recommendation must use current requirements")
        if self.report is not None:
            if self.status != "ready" or self.report.choices != self.recommendation.recommendations:
                raise ValueError("Report must reuse current ranked evidence")
            if self.report.requirements_revision != self.requirements.revision or self.report.catalog_sha256 != self.recommendation.catalog.sha256:
                raise ValueError("Report snapshot mismatch")
        return self
