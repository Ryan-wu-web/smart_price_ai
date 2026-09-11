"""Navigation cards are not model-generated product claims."""
from app.models.schemas import SuggestionCard


class SuggestionService:
    async def generate_cards(self, category: str, brand: str = "", color: str = "") -> list[SuggestionCard]:
        cards = [
            SuggestionCard(type="lowest_price", title="浏览样例商品", description="查看本地虚构商品及样例价格区间，不是全网比价"),
            SuggestionCard(type="price_trend", title="历史价格说明", description="当前未接入历史价格，不能判断购买时机"),
            SuggestionCard(type="similar_style", title="同品类样例", description="在本地知识库中按条件浏览，不代表真实热销商品"),
        ]
        if color:
            cards.append(SuggestionCard(type="filter_color", title="按颜色筛选样例", description="精确筛选颜色；无匹配时不会自动放宽"))
        return cards
