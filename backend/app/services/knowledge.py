"""Read-only, validated catalog snapshot. No network, model or random prices."""
import hashlib
import json
import logging
from pathlib import Path

from app.models.knowledge import (
    CatalogDocument, CatalogInfo, CatalogQuery, EvidenceResponse,
    ProductDetailResponse, ProductFacts, ProductListResponse,
)

logger = logging.getLogger(__name__)
DEFAULT_CATALOG_PATH = Path(__file__).resolve().parents[1] / "catalog" / "sample-products.v1.json"
MAX_CATALOG_BYTES = 2_000_000


class CatalogUnavailable(Exception):
    def __init__(self):
        super().__init__("样例商品库暂时不可用，请稍后重试。")


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate catalog JSON key")
        result[key] = value
    return result


def _reject_constant(value):
    raise ValueError("Non-finite catalog value")


class ProductCatalog:
    """Load once per worker; return copies so callers cannot mutate stored facts.

    A supplied path is for local construction only, never accepted from an API.
    Invalid files fail closed; they are never replaced with legacy MockDataSource.
    """
    def __init__(self, path: Path = DEFAULT_CATALOG_PATH):
        try:
            with path.open("rb") as stream:
                raw = stream.read(MAX_CATALOG_BYTES + 1)
            if len(raw) > MAX_CATALOG_BYTES:
                raise ValueError("Catalog exceeds size limit")
            document = CatalogDocument.model_validate(json.loads(
                raw.decode("utf-8"), object_pairs_hook=_unique_object,
                parse_constant=_reject_constant,
            ))
        except (OSError, UnicodeError, ValueError, RecursionError) as exc:
            # Never print paths, source content or validation input.
            logger.error("catalog_load_failed type=%s", type(exc).__name__)
            raise CatalogUnavailable() from None
        self._products = {p.product_id: p for p in document.products}
        self._sources = {s.source_id: s for s in document.sources}
        self._evidence = {p.evidence_id: (index, p) for index, p in enumerate(document.products)}
        self._info = CatalogInfo(
            schema_version=document.schema_version, dataset_id=document.dataset_id,
            revision=document.revision, sha256=hashlib.sha256(raw).hexdigest(),
            product_count=len(document.products), notice=document.notice,
        )
        logger.info("catalog_loaded dataset=%s revision=%s products=%d sha256=%s",
                    self._info.dataset_id, self._info.revision,
                    self._info.product_count, self._info.sha256)

    def iter_products(self):
        """Yield isolated facts for index construction, without pagination truncation."""
        for product in self._products.values():
            yield product.model_copy(deep=True)

    def info(self) -> CatalogInfo:
        return self._info.model_copy(deep=True)

    def list_products(self, *, category: str | None = None, brand: str | None = None,
                      limit: int = 20, offset: int = 0) -> ProductListResponse:
        query = CatalogQuery(category=category, brand=brand, limit=limit, offset=offset)
        # This is exact metadata browsing, not relevance retrieval or recommendation.
        # Unknown filters return no matches; never relax a condition silently.
        matches = sorted((p for p in self._products.values()
                          if (query.category is None or p.category == query.category)
                          and (query.brand is None or p.brand == query.brand)),
                         key=lambda p: p.product_id)
        return ProductListResponse(
            catalog=self.info(), total=len(matches), limit=query.limit, offset=query.offset,
            products=[p.model_copy(deep=True) for p in matches[query.offset:query.offset + query.limit]],
        )

    def get_product(self, product_id: str) -> ProductDetailResponse | None:
        product = self._products.get(product_id)
        if product is None:
            return None
        return ProductDetailResponse(catalog=self.info(), product=product.model_copy(deep=True))

    def get_evidence(self, evidence_id: str) -> EvidenceResponse | None:
        entry = self._evidence.get(evidence_id)
        if entry is None:
            return None
        index, product = entry
        # Derive evidence from the same validated facts, not duplicated prose.
        fields = ProductFacts.model_validate({
            key: value for key, value in product.model_dump().items()
            if key in ProductFacts.model_fields
        })
        return EvidenceResponse(
            catalog=self.info(), evidence_id=evidence_id, product_id=product.product_id,
            source=self._sources[product.source_id].model_copy(deep=True),
            locator=f"/products/{index}", fields=fields,
        )
