"""Central, immutable relevance settings; NOT shopping preference weights."""
from dataclasses import dataclass, fields
import math

ALGORITHM_VERSION = "field-hybrid-v1"
# Human labels and roles do not add product facts to evidence.
FIELD_SPECS = (
    ("name", "商品名称", "identity"), ("category", "品类", "identity"),
    ("brand", "品牌", "identity"), ("model", "型号", "identity"),
    ("parameters", "参数", "fact"), ("price_range", "样例价格区间", "fact"),
    ("use_cases", "适用场景", "benefit"), ("advantages", "优点", "benefit"),
    ("disadvantages", "缺点", "caveat"), ("exclusions", "排斥场景", "caveat"),
    ("buying_advice", "选购建议", "advice"),
)
ROLE_QUALITY = {"identity": 1.0, "fact": 1.0, "benefit": 0.9, "caveat": 0.5, "advice": 0.6}


@dataclass(frozen=True)
class RetrievalConfig:
    bm25_k1: float = 1.2
    bm25_b: float = 0.75
    vector_min_similarity: float = 0.08
    vector_ngram_min: int = 2
    vector_ngram_max: int = 4
    rrf_k: int = 60
    candidate_pool: int = 40  # Per channel, after exact metadata filtering.
    keyword_weight: float = 0.5
    vector_weight: float = 0.5
    fusion_weight: float = 0.6
    coverage_weight: float = 0.3
    field_weight: float = 0.1
    evidence_limit: int = 5
    max_chunks: int = 20_000
    max_vocabulary: int = 200_000

    def __post_init__(self):
        for field in fields(self):
            value = getattr(self, field.name)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
                raise ValueError("Retrieval settings must be finite numbers")
            if field.type is int and (not isinstance(value, int) or value < 1):
                raise ValueError("Retrieval counts must be positive integers")
        if self.bm25_k1 <= 0 or not 0 <= self.bm25_b <= 1:
            raise ValueError("Invalid BM25 settings")
        if not 0 < self.vector_min_similarity <= 1 or not 2 <= self.vector_ngram_min <= self.vector_ngram_max <= 5:
            raise ValueError("Invalid character vector settings")
        if self.candidate_pool < 10 or self.evidence_limit > 10:
            raise ValueError("Invalid retrieval limits")
        for weights in [(self.keyword_weight, self.vector_weight),
                        (self.fusion_weight, self.coverage_weight, self.field_weight)]:
            if any(w < 0 for w in weights) or not math.isclose(sum(weights), 1.0):
                raise ValueError("Non-negative scoring weights must sum to one")


DEFAULT_RETRIEVAL_CONFIG = RetrievalConfig()
