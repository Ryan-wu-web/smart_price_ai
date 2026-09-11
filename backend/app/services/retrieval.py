"""Small offline hybrid index: BM25 + sparse character TF-IDF + product RRF.

No network, embeddings provider, random fallback, constraint inference or LLM.
Every returned value is an exact field/list item from the versioned catalog.
"""
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
import hashlib
import json
import logging
import math
import re
import unicodedata

from app.core.retrieval_config import (
    ALGORITHM_VERSION, DEFAULT_RETRIEVAL_CONFIG, FIELD_SPECS, ROLE_QUALITY, RetrievalConfig,
)
from app.models.retrieval import (
    MatchedEvidence, RelevanceScores, RetrievalIndexInfo, RETRIEVAL_WARNINGS,
    SearchHit, SearchRequest, SearchResponse,
)
from app.services.knowledge import ProductCatalog

logger = logging.getLogger(__name__)
_SEGMENTS = re.compile(r"[\u3400-\u9fff]+|[a-z0-9]+(?:[-_][a-z0-9]+)*")


def _segments(text: str) -> list[str]:
    return _SEGMENTS.findall(unicodedata.normalize("NFKC", text).casefold())


def keyword_tokens(text: str) -> list[str]:
    result = []
    for part in _segments(text):
        if '\u3400' <= part[0] <= '\u9fff':
            if len(part) > 1:
                result.extend(part[i:i + 2] for i in range(len(part) - 1))
            else:
                result.append(part)
        else:
            result.append(part)
    return result


def vector_terms(text: str, config: RetrievalConfig = DEFAULT_RETRIEVAL_CONFIG) -> list[str]:
    # No cross-word/punctuation grams and no unigram fallback that fabricates OOV hits.
    terms = []
    for part in _segments(text):
        if part.isdecimal():
            # 650g must not match an unrelated serial number merely containing "65".
            terms.append(f"number:{part}")
            continue
        for n in range(config.vector_ngram_min, config.vector_ngram_max + 1):
            terms.extend(part[i:i + n] for i in range(len(part) - n + 1)
                         if not part[i:i + n].isdecimal())
    return terms


class RetrievalUnavailable(Exception):
    def __init__(self):
        super().__init__("样例商品检索暂时不可用，请稍后重试。")


@dataclass(frozen=True)
class _Chunk:
    product_id: str
    evidence_id: str
    source_id: str
    field: str
    locator: str
    label: str
    role: str
    value_json: str
    text: str


class ProductRetriever:
    """Immutable index built from one catalog snapshot. Search uses only local state."""

    def __init__(self, catalog: ProductCatalog, config: RetrievalConfig = DEFAULT_RETRIEVAL_CONFIG):
        self._config = config
        try:
            self._build(catalog)
        except Exception as exc:
            # Restrict failure to the optional index; never log facts, query or exception text.
            logger.error("retrieval_build_failed type=%s", type(exc).__name__)
            raise RetrievalUnavailable() from None

    def _build(self, catalog):
        self._catalog_info = catalog.info()
        self._products = {}
        self._chunks = []
        for product in catalog.iter_products():
            self._products[product.product_id] = product
            evidence = catalog.get_evidence(product.evidence_id)
            facts = evidence.fields.model_dump()
            for field, label, role in FIELD_SPECS:
                value = facts[field]
                if field == "parameters":
                    items = [(f"{field}/{key}", param["label"], param) for key, param in value.items()]
                elif isinstance(value, list):
                    items = [(f"{field}/{i}", label, item) for i, item in enumerate(value)]
                else:
                    items = [(field, label, value)]
                for path, item_label, item in items:
                    raw = json.dumps(item, ensure_ascii=False, sort_keys=True, allow_nan=False)
                    # Keep raw JSON as value; render facts only (no invented yes/no parameters).
                    if isinstance(item, dict) and field == "parameters":
                        rendered = json.dumps(item["value"], ensure_ascii=False)
                        text = f'{item_label}: {rendered} {item["unit"] or ""}'.strip()
                    else:
                        text = raw if not isinstance(item, str) else item
                    self._chunks.append(_Chunk(product.product_id, product.evidence_id,
                        product.source_id, path, f"{evidence.locator}/{path}", item_label, role, raw, text))
                    if len(self._chunks) > self._config.max_chunks:
                        raise ValueError("Chunk limit exceeded")
        self._chunks = tuple(self._chunks)
        self._keyword = self._postings(keyword_tokens)
        self._lengths = [len(keyword_tokens(c.text)) for c in self._chunks]
        self._average_length = sum(self._lengths) / len(self._chunks) or 1.0
        vector_postings = self._postings(lambda text: vector_terms(text, self._config))
        size = len(self._chunks)
        self._idf = {term: math.log((size + 1) / (len(docs) + 1)) + 1 for term, docs in vector_postings.items()}
        norms = defaultdict(float)
        weighted = {}
        for term, docs in vector_postings.items():
            weighted[term] = {}
            for i, tf in docs.items():
                weight = (1 + math.log(tf)) * self._idf[term]
                weighted[term][i] = weight
                norms[i] += weight * weight
        self._vector = {term: {i: weight / math.sqrt(norms[i]) for i, weight in docs.items()}
                        for term, docs in weighted.items()}
        signature = json.dumps({"algorithm": ALGORITHM_VERSION, "config": asdict(self._config),
            "fields": FIELD_SPECS, "roles": ROLE_QUALITY, "catalog": self._catalog_info.model_dump()},
            ensure_ascii=False, sort_keys=True, allow_nan=False).encode("utf-8")
        self._index_info = RetrievalIndexInfo(algorithm=ALGORITHM_VERSION,
            fingerprint=hashlib.sha256(signature).hexdigest(), chunk_count=size,
            keyword_vocabulary=len(self._keyword), vector_vocabulary=len(self._vector))
        logger.info("retrieval_ready chunks=%d fingerprint=%s", size, self._index_info.fingerprint)

    def _postings(self, tokenize):
        postings = defaultdict(dict)
        for i, chunk in enumerate(self._chunks):
            for term, count in Counter(tokenize(chunk.text)).items():
                postings[term][i] = count
                if len(postings) > self._config.max_vocabulary:
                    raise ValueError("Vocabulary limit exceeded")
        return dict(postings)

    def _keyword_scores(self, terms, eligible):
        scores = defaultdict(float)
        cfg = self._config
        size = len(self._chunks)
        for term in sorted(terms):
            docs = self._keyword.get(term, {})
            idf = math.log(1 + (size - len(docs) + 0.5) / (len(docs) + 0.5))
            for i, tf in docs.items():
                if self._chunks[i].product_id in eligible:
                    norm = cfg.bm25_k1 * (1 - cfg.bm25_b + cfg.bm25_b * self._lengths[i] / self._average_length)
                    scores[i] += idf * tf * (cfg.bm25_k1 + 1) / (tf + norm)
        return dict(scores)

    def _vector_scores(self, query, eligible):
        weights = {term: (1 + math.log(tf)) * self._idf[term]
                   for term, tf in Counter(vector_terms(query, self._config)).items() if term in self._idf}
        norm = math.sqrt(sum(w * w for w in weights.values()))
        scores = defaultdict(float)
        if norm:
            for term, weight in sorted(weights.items()):
                for i, value in self._vector[term].items():
                    if self._chunks[i].product_id in eligible:
                        scores[i] += (weight / norm) * value
        return {i: min(1.0, score) for i, score in scores.items() if score >= self._config.vector_min_similarity}

    def _product_ranks(self, scores):
        best = defaultdict(float)
        for i, score in scores.items():
            product = self._chunks[i].product_id
            best[product] = max(best[product], score)
        ordered = sorted(best, key=lambda p: (-best[p], p))[:self._config.candidate_pool]
        return {p: rank for rank, p in enumerate(ordered, 1)}, best

    def search(self, request: SearchRequest) -> SearchResponse:
        request = SearchRequest.model_validate(request.model_dump())
        cfg = self._config
        eligible = {p.product_id for p in self._products.values()
                    if (request.category is None or p.category == request.category)
                    and (request.brand is None or p.brand == request.brand)}
        terms = set(keyword_tokens(request.query))
        kw = self._keyword_scores(terms, eligible) if request.mode != "vector" else {}
        vec = self._vector_scores(request.query, eligible) if request.mode != "keyword" else {}
        kr, kb = self._product_ranks(kw)
        vr, vb = self._product_ranks(vec)
        candidates = kr.keys() | vr.keys()
        # Single-channel diagnostics use full channel weight, not half a hybrid vote.
        weights = (cfg.keyword_weight, cfg.vector_weight) if request.mode == "hybrid" else (
            (1.0, 0.0) if request.mode == "keyword" else (0.0, 1.0))
        matched = defaultdict(list)
        for i in kw.keys() | vec.keys():
            chunk = self._chunks[i]
            if chunk.product_id in candidates:
                matched[chunk.product_id].append(i)
        hits = []
        for product_id in sorted(candidates):
            product = self._products[product_id]
            # Evidence order has no free extra weights: best text-channel score, then role.
            indices = sorted(matched[product_id], key=lambda i: (
                -max(kw.get(i, 0) / (1 + kw.get(i, 0)), vec.get(i, 0)),
                -ROLE_QUALITY[self._chunks[i].role], self._chunks[i].field))[:cfg.evidence_limit]
            evidence = []
            covered = set()
            for i in indices:
                chunk = self._chunks[i]
                found = sorted(terms & set(keyword_tokens(chunk.text)))
                covered.update(found)
                evidence.append(MatchedEvidence(chunk_id=f"{chunk.evidence_id}/{chunk.field}",
                    product_id=product_id, evidence_id=chunk.evidence_id, source_id=chunk.source_id,
                    field=chunk.field, locator=chunk.locator, label=chunk.label, role=chunk.role,
                    value=json.loads(chunk.value_json), text=chunk.text, matched_terms=found,
                    keyword_score=kw.get(i, 0.0), vector_similarity=vec.get(i, 0.0)))
            fusion = (cfg.rrf_k + 1) * sum(w / (cfg.rrf_k + rank) for w, rank in
                [(weights[0], kr.get(product_id)), (weights[1], vr.get(product_id))] if rank is not None)
            coverage = len(covered) / len(terms) if terms else 0.0
            quality = max(ROLE_QUALITY[e.role] for e in evidence)
            score = cfg.fusion_weight * fusion + cfg.coverage_weight * coverage + cfg.field_weight * quality
            reasons = []
            if product_id in kr:
                reasons.append(f"关键词通道第{kr[product_id]}名；命中词项：{'、'.join(sorted(covered)) or '见证据'}")
            if product_id in vr:
                reasons.append(f"字符向量通道第{vr[product_id]}名；最高相似度{vb[product_id]:.3f}")
            reasons.append("按通道名次融合、证据词项覆盖率和字段类型重排；仅用于相关资料检索。")
            if any(e.role == "caveat" for e in evidence):
                reasons.append("含缺点或排斥场景命中，请勿作为正向推荐理由。")
            hits.append(SearchHit(product_id=product_id, evidence_id=product.evidence_id,
                name=product.name, category=product.category, brand=product.brand, model=product.model,
                score=score, scores=RelevanceScores(keyword_score=kb.get(product_id, 0.0),
                    vector_similarity=vb.get(product_id, 0.0), keyword_rank=kr.get(product_id),
                    vector_rank=vr.get(product_id), fusion=fusion, coverage=coverage, field_quality=quality),
                matched_fields=[e.field for e in evidence], match_reasons=reasons, evidence=evidence))
        hits.sort(key=lambda h: (-h.score, h.product_id))
        response = SearchResponse(catalog=self._catalog_info.model_copy(deep=True),
            index=self._index_info.model_copy(deep=True), request=request, eligible_products=len(eligible),
            recalled_products=len(candidates), empty_reason=("no_metadata_match" if not eligible else
                "no_term_match" if not hits else None), hits=hits[:request.top_k], warnings=list(RETRIEVAL_WARNINGS))
        logger.info("retrieval_finished mode=%s eligible=%d recalled=%d returned=%d empty=%s",
            request.mode, len(eligible), len(candidates), len(response.hits), response.empty_reason)
        return response
