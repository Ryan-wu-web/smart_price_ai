"""Validated local knowledge facts; deliberately separate from legacy mock offers."""
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

Identifier = Annotated[str, Field(pattern=r"^[a-z0-9][a-z0-9_-]{0,63}$")]
Text = Annotated[str, Field(min_length=1, max_length=500)]
ShortText = Annotated[str, Field(min_length=1, max_length=80)]
FactList = Annotated[list[Text], Field(min_length=1, max_length=30)]
SAMPLE_NOTICE = "本地虚构样例商品与价格，仅用于功能演示和工程评测，不代表真实商品参数、在售报价或历史价格。"


class KnowledgeModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid", strict=True, str_strip_whitespace=True, allow_inf_nan=False,
    )


class KnowledgeParameter(KnowledgeModel):
    label: ShortText
    # Bool before numbers preserves JSON types through FastAPI/Pydantic.
    # Null means unknown, never zero/false. Numeric units remain explicit.
    value: Annotated[str, Field(min_length=1, max_length=200)] | bool | int | float | None
    unit: Annotated[str, Field(min_length=1, max_length=30)] | None = None


class PriceRange(KnowledgeModel):
    min: float = Field(ge=0, le=100_000_000)
    max: float = Field(ge=0, le=100_000_000)
    currency: Literal["CNY"] = "CNY"

    @model_validator(mode="after")
    def ordered(self):
        if self.min > self.max:
            raise ValueError("Price range is reversed")
        return self


class ProductFacts(KnowledgeModel):
    name: Text
    category: ShortText
    brand: ShortText
    model: ShortText
    parameters: dict[Identifier, KnowledgeParameter] = Field(min_length=1, max_length=50)
    price_range: PriceRange
    use_cases: FactList
    advantages: FactList
    disadvantages: FactList
    # Product unsuitability statements, not inferred user preferences.
    exclusions: FactList
    buying_advice: FactList


class ProductKnowledge(ProductFacts):
    product_id: Identifier
    source_id: Identifier
    evidence_id: Identifier
    data_kind: Literal["sample"]


class KnowledgeSource(KnowledgeModel):
    source_id: Identifier
    kind: Literal["local_synthetic"]
    title: Text
    description: Text


class CatalogDocument(KnowledgeModel):
    schema_version: Literal[1]
    dataset_id: Identifier
    revision: ShortText
    notice: Literal[SAMPLE_NOTICE]
    sources: list[KnowledgeSource] = Field(min_length=1, max_length=100)
    products: list[ProductKnowledge] = Field(min_length=1, max_length=5000)

    @model_validator(mode="after")
    def references_are_unique(self):
        source_ids = [s.source_id for s in self.sources]
        product_ids = [p.product_id for p in self.products]
        evidence_ids = [p.evidence_id for p in self.products]
        for ids in (source_ids, product_ids, evidence_ids):
            if len(ids) != len(set(ids)):
                raise ValueError("Duplicate catalog identifier")
        if any(p.source_id not in source_ids for p in self.products):
            raise ValueError("Unresolved catalog source")
        return self


class CatalogInfo(KnowledgeModel):
    schema_version: Literal[1]
    dataset_id: Identifier
    revision: ShortText
    sha256: Annotated[str, Field(pattern=r"^[0-9a-f]{64}$")]
    product_count: int = Field(ge=0)
    data_kind: Literal["sample"] = "sample"
    notice: Literal[SAMPLE_NOTICE] = SAMPLE_NOTICE


class CatalogQuery(KnowledgeModel):
    category: ShortText | None = None
    brand: ShortText | None = None
    limit: int = Field(default=20, ge=1, le=100)
    offset: int = Field(default=0, ge=0)


class ProductListResponse(KnowledgeModel):
    catalog: CatalogInfo
    total: int = Field(ge=0, description="Number matching filters, before pagination")
    limit: int = Field(ge=1, le=100)
    offset: int = Field(ge=0)
    products: list[ProductKnowledge]


class ProductDetailResponse(KnowledgeModel):
    catalog: CatalogInfo
    product: ProductKnowledge


class EvidenceResponse(KnowledgeModel):
    catalog: CatalogInfo
    evidence_id: Identifier
    product_id: Identifier
    source: KnowledgeSource
    locator: str = Field(pattern=r"^/products/[0-9]+$", description="JSON Pointer inside the hashed catalog")
    fields: ProductFacts
