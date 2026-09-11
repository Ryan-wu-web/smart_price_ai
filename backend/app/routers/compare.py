from typing import Annotated, Literal

from fastapi import APIRouter, Query

from app.models.schemas import CompareQuery, CompareResponse
from app.routers.knowledge import CatalogDependency
from app.services.comparison import ComparisonService

router = APIRouter(prefix="/api/v1", tags=["compare"])
Filter = Annotated[str | None, Query(min_length=1, max_length=80, pattern=r"\S")]


@router.get("/compare", response_model=CompareResponse)
def compare(
    catalog: CatalogDependency,
    category: Annotated[str, Query(min_length=1, max_length=80, pattern=r"\S")],
    brand: Filter = None, color: Filter = None,
    sort_by: Literal["price", "rating"] | None = None,
    filter_mode: Literal["official", "similar"] | None = None,
):
    query = CompareQuery(category=category, brand=brand, color=color,
                         sort_by=sort_by, filter_mode=filter_mode)
    products = ComparisonService(catalog).compare(query)
    explanation = "严格按品类、品牌和颜色筛选；price 是样例区间下限，并非在售报价。"
    if filter_mode == "official":
        explanation += "样例库没有官方渠道证据，因此返回空结果。"
    elif not products:
        explanation += "没有满足当前条件的样例，未放宽条件。"
    if sort_by == "rating":
        explanation += "没有评分证据，使用固定商品ID顺序，不代表好评排名。"
    return CompareResponse(products=products, catalog=catalog.info(), explanation=explanation)
