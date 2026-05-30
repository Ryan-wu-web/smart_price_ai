from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class RecognizeRequest(BaseModel):
    image_base64: str = Field(..., min_length=1, max_length=15_000_000, description="Base64 编码的商品图片")


class RecognizeResponse(BaseModel):
    name: str = Field(..., description="商品名称")
    brand: str = Field(default="", description="品牌")
    category: str = Field(..., description="品类")
    color: str = Field(default="", description="颜色")
    material: str = Field(default="", description="材质")
    style: str = Field(default="", description="款式")


class SuggestionCard(BaseModel):
    type: str = Field(..., description="卡片类型")
    title: str = Field(..., description="卡片标题")
    description: str = Field(..., description="卡片描述")


class SuggestResponse(BaseModel):
    cards: list[SuggestionCard] = Field(..., description="建议卡片列表")


class ProductBase(BaseModel):
    name: str
    brand: str
    category: str
    color: str
    price: float = Field(..., ge=0)
    platform: str
    rating: float = Field(default=0.0, ge=0, le=5)
    tags: list[str] = Field(default_factory=list)
    original_price: float = Field(default=0.0, ge=0)
    image_url: str = Field(default="")


class ProductResponse(ProductBase):
    id: str
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        from_attributes = True


class CompareQuery(BaseModel):
    category: str
    brand: Optional[str] = None
    color: Optional[str] = None
    sort_by: Optional[str] = Field(default=None, pattern="^(price|rating)$")
    filter_mode: Optional[str] = Field(default=None, pattern="^(official|similar)$")


class CompareResponse(BaseModel):
    products: list[ProductResponse]


class FilterRequest(BaseModel):
    query_text: str = Field(..., min_length=1, description="自然语言筛选条件")


class FilterResponse(BaseModel):
    filters: dict[str, Any] = Field(..., description="解析后的筛选条件")


class TrendResponse(BaseModel):
    trend: str = Field(..., description="趋势描述")
    advice: str = Field(..., description="购买建议")
    confidence: float = Field(..., ge=0, le=1, description="置信度")
    history_prices: list[dict] = Field(default_factory=list, description="历史价格数据，每项含 date/price/platform")


class ReportRequest(BaseModel):
    product_name: str
    best_choice: dict[str, Any]
    alternatives: list[dict[str, Any]] = Field(default_factory=list)


class ReportResponse(BaseModel):
    summary: str
    pros: list[str]
    cons: list[str]
    recommendation: str


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000)
    session_id: Optional[str] = None
    current_product: Optional[dict[str, Any]] = None


class ChatResponse(BaseModel):
    reply: str
    action: str = Field(default="none")
    action_data: dict[str, Any] = Field(default_factory=dict)
    session_id: str
