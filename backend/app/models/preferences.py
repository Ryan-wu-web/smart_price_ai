"""Explicit local-user stable preferences; not a model memory sink."""
from typing import Literal
from pydantic import Field, model_validator
from app.models.requirements import ConditionInput, RequirementModel

class PreferenceItem(RequirementModel):
    id: str = Field(pattern=r"^[a-zA-Z0-9_-]{1,64}$")
    condition: ConditionInput
    category: Literal["耳机", "运动鞋", "双肩包"] | None = None
    confirmation_text: str = Field(min_length=1, max_length=500)

    @model_validator(mode="after")
    def stable_only(self):
        if self.condition.field not in ("budget", "brand", "use_case"):
            raise ValueError("Only explicit stable budgets, brands and use/exclusion preferences may be stored")
        return self

class PreferenceProfile(RequirementModel):
    version: Literal[1] = 1
    revision: int = Field(default=0, ge=0)
    items: list[PreferenceItem] = Field(default_factory=list, max_length=32)
    storage: Literal["local_sqlite"] = "local_sqlite"
    notice: str = "仅保存你明确确认的稳定偏好；应用到本轮前再次确认，不会自动覆盖现有条件。"

    @model_validator(mode="after")
    def unique(self):
        if len({item.id for item in self.items}) != len(self.items):
            raise ValueError("Duplicate preference ID")
        return self

class PreferenceUpdate(RequirementModel):
    expected_revision: int = Field(ge=0)
    confirmed: bool
    items: list[PreferenceItem] = Field(max_length=32)

    @model_validator(mode="after")
    def unique(self):
        if not self.confirmed:
            raise ValueError("Saving preferences requires explicit confirmation")
        PreferenceProfile(items=self.items)
        return self
