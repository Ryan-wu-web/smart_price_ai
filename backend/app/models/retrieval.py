"""Validated retrieval contract: evidence relevance is not constraint satisfaction."""
from typing import Annotated, Literal
import unicodedata

from pydantic import Field, JsonValue, field_validator

from app.models.knowledge import CatalogInfo, Identifier, KnowledgeModel, ShortText

SearchMode = Literal["hybrid", "keyword", "vector"]
Score = Annotated[float, Field(ge=0, le=1)]
RETRIEVAL_WARNINGS = (
    "检索相关性不代表商品符合预算、功能或排斥条件；本接口不执行购物硬约束判断。",
    "缺点、排斥条件及参数false/null也可能命中；请阅读原始证据，未知值不能推断为支持。",
    "向量通道为本地字符TF-IDF，不是预训练语义Embedding；同义表达或未收录商品可能无匹配。",
)


class SearchRequest(KnowledgeModel):
    query: str = Field(min_length=1, max_length=240)
    category: ShortText | None = None
    brand: ShortText | None = None
    top_k: int = Field(default=5, ge=1, le=10)
    mode: SearchMode = "hybrid"

    @field_validator("query")
    @classmethod
    def searchable(cls, value):
        normalized = unicodedata.normalize("NFKC", value)
        if len(normalized) > 480 or not any(c.isalnum() for c in normalized):
            raise ValueError("Query must contain searchable text")
        return value


class RetrievalIndexInfo(KnowledgeModel):
    algorithm: str
    fingerprint: str = Field(pattern=r"^[0-9a-f]{64}$")
    chunk_count: int = Field(ge=1)
    keyword_vocabulary: int = Field(ge=1)
    vector_vocabulary: int = Field(ge=1)
    vector_method: Literal["character_tfidf"] = "character_tfidf"


class MatchedEvidence(KnowledgeModel):
    chunk_id: str
    product_id: Identifier
    evidence_id: Identifier
    source_id: Identifier
    field: str
    locator: str = Field(pattern=r"^/products/[0-9]+/")
    label: str
    role: Literal["identity", "fact", "benefit", "caveat", "advice"]
    value: JsonValue
    text: str
    matched_terms: list[str]
    keyword_score: float = Field(ge=0)
    vector_similarity: Score


class RelevanceScores(KnowledgeModel):
    keyword_score: float = Field(ge=0)
    vector_similarity: Score
    keyword_rank: int | None = Field(default=None, ge=1)
    vector_rank: int | None = Field(default=None, ge=1)
    fusion: Score
    coverage: Score
    field_quality: Score


class SearchHit(KnowledgeModel):
    product_id: Identifier
    evidence_id: Identifier
    name: str
    category: ShortText
    brand: ShortText
    model: ShortText
    score: Score
    scores: RelevanceScores
    matched_fields: list[str] = Field(min_length=1)
    match_reasons: list[str] = Field(min_length=1)
    evidence: list[MatchedEvidence] = Field(min_length=1, max_length=10)


class SearchResponse(KnowledgeModel):
    catalog: CatalogInfo
    index: RetrievalIndexInfo
    request: SearchRequest
    eligible_products: int = Field(ge=0)
    recalled_products: int = Field(ge=0)
    empty_reason: Literal["no_metadata_match", "no_term_match"] | None = None
    hits: list[SearchHit] = Field(max_length=10)
    warnings: list[str]
