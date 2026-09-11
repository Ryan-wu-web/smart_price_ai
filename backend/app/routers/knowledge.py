"""Read-only sample knowledge API, additive to existing shopping routes."""
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, Query, Request

from app.models.knowledge import (
    EvidenceResponse, ProductDetailResponse, ProductListResponse,
)
from app.services.knowledge import ProductCatalog

router = APIRouter(prefix="/api/v1/knowledge", tags=["sample-knowledge"])


def get_catalog(request: Request) -> ProductCatalog:
    catalog = getattr(request.app.state, "product_catalog", None)
    if catalog is None:
        raise HTTPException(status_code=503, detail={
            "code": "CATALOG_UNAVAILABLE", "message": "样例商品库暂时不可用，请稍后重试。",
        })
    return catalog


CatalogDependency = Annotated[ProductCatalog, Depends(get_catalog)]
FilterText = Annotated[str | None, Query(min_length=1, max_length=80, pattern=r"\S")]
SafeId = Annotated[str, Path(pattern=r"^[a-z0-9][a-z0-9_-]{0,63}$")]


@router.get("/products", response_model=ProductListResponse)
def list_products(
    catalog: CatalogDependency,
    category: FilterText = None,
    brand: FilterText = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
):
    return catalog.list_products(category=category, brand=brand, limit=limit, offset=offset)


@router.get("/products/{product_id}", response_model=ProductDetailResponse)
def get_product(product_id: SafeId, catalog: CatalogDependency):
    product = catalog.get_product(product_id)
    if product is None:
        raise HTTPException(status_code=404, detail={
            "code": "PRODUCT_NOT_FOUND", "message": "样例商品不存在，请重新选择。",
        })
    return product


@router.get("/evidence/{evidence_id}", response_model=EvidenceResponse)
def get_evidence(evidence_id: SafeId, catalog: CatalogDependency):
    evidence = catalog.get_evidence(evidence_id)
    if evidence is None:
        raise HTTPException(status_code=404, detail={
            "code": "EVIDENCE_NOT_FOUND", "message": "对应样例证据不存在。",
        })
    return evidence
