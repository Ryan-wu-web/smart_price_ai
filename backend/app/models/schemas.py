from datetime import datetime
import math
import re
from typing import Annotated, Any, Literal, Optional

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, model_validator

from app.models.workflow import ShoppingInput


class RecognizeRequest(BaseModel):
    image_base64: str = Field(..., min_length=1, max_length=15_000_000, description="Base64 编码的商品图片")


class RecognizeResponse(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    name: str = Field(..., min_length=1, description="商品名称")
    brand: str = Field(default="", description="品牌")
    category: str = Field(..., min_length=1, description="品类")
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


def validate_session_id(value: str) -> str:
    # Keep existing safe IDs, but disallow Windows device names and path syntax.
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", value):
        raise ValueError("会话 ID 格式无效，请重新开始对话。")
    if re.fullmatch(r"(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])", value):
        raise ValueError("会话 ID 格式无效，请重新开始对话。")
    return value


SessionId = Annotated[str, Field(strict=True, min_length=1, max_length=64), AfterValidator(validate_session_id)]


class ChatProduct(BaseModel):
    """Client-selected/recognized context, not a verified catalog record."""
    model_config = ConfigDict(str_strip_whitespace=True, populate_by_name=True)

    name: str = Field(min_length=1, max_length=200)
    id: str | None = Field(default=None, max_length=200)
    brand: str | None = Field(default=None, max_length=200)
    category: str | None = Field(default=None, max_length=200)
    color: str | None = Field(default=None, max_length=200)
    material: str | None = Field(default=None, max_length=200)
    style: str | None = Field(default=None, max_length=200)
    price: float | None = Field(default=None, ge=0, allow_inf_nan=False, strict=True)
    platform: str | None = Field(default=None, max_length=200)
    rating: float | None = Field(default=None, ge=0, le=5, allow_inf_nan=False, strict=True)
    tags: list[Annotated[str, Field(max_length=100)]] | None = Field(default=None, max_length=30)
    image_url: str | None = Field(default=None, max_length=2000, alias="imageUrl")
    original_price: float | None = Field(default=None, ge=0, allow_inf_nan=False, strict=True, alias="originalPrice")


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000)
    session_id: SessionId | None = None
    current_product: ChatProduct | None = None
    shopping: ShoppingInput | None = None

    @model_validator(mode="after")
    def nonblank_message(self):
        if not self.message.strip():
            raise ValueError("请输入消息内容。")
        return self


class ChatModelResult(BaseModel):
    reply: str = Field(min_length=1, max_length=16000)
    action: Literal["none", "report", "trend", "filter", "compare"] = "none"
    action_data: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def nonblank_reply(self):
        if not self.reply.strip():
            raise ValueError("reply must not be blank")
        return self


class ChatSummary(BaseModel):
    summary: str = Field(min_length=1, max_length=6000)

    @model_validator(mode="after")
    def nonblank_summary(self):
        if not self.summary.strip():
            raise ValueError("summary must not be blank")
        return self


class ChatResponse(ChatModelResult):
    session_id: SessionId
    current_product: ChatProduct | None = None


class ImageCenter(BaseModel):
    model_config = ConfigDict(extra="forbid")

    x: float = Field(ge=0, le=1, allow_inf_nan=False, strict=True)
    y: float = Field(ge=0, le=1, allow_inf_nan=False, strict=True)


class RecognizedObject(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    name: str = Field(min_length=1)
    brand: str = ""
    category: str = Field(min_length=1)
    color: str = ""
    center: ImageCenter

    @model_validator(mode="before")
    @classmethod
    def legacy_bbox(cls, value):
        """Accept legacy normalized x/y/w/h boxes, never invent a (0, 0) point."""
        if not isinstance(value, dict) or "center" in value or "bbox" not in value:
            return value
        bbox = value["bbox"]
        if isinstance(bbox, dict) and all(k in bbox for k in ("x", "y", "w", "h")):
            coords = [bbox[k] for k in ("x", "y", "w", "h")]
        elif isinstance(bbox, list) and len(bbox) == 4:
            coords = bbox
        else:
            raise ValueError("bbox requires x, y, w, h")
        if any(type(v) not in (int, float) or not math.isfinite(v) or not 0 <= v <= 1 for v in coords):
            raise ValueError("bbox must use finite normalized coordinates")
        x, y, w, h = coords
        if x + w > 1 or y + h > 1:
            raise ValueError("bbox exceeds image bounds")
        return {**value, "center": {"x": x + w / 2, "y": y + h / 2}}



class RecognizeMultiResponse(BaseModel):
    objects: list[RecognizedObject]
