from app.core.llm_client import LLMClient
from app.core.prompt_engine import PromptEngine
from app.models.schemas import SuggestionCard


class SuggestionService:
    def __init__(self, llm_client: LLMClient | None = None):
        self.llm_client = llm_client or LLMClient()

    async def generate_cards(
        self, category: str, brand: str = "", color: str = ""
    ) -> list[SuggestionCard]:
        prompt = PromptEngine.suggestion_cards(category, brand, color)
        messages = [{"role": "user", "content": prompt}]
        result = await self.llm_client.chat_json(messages)
        if not isinstance(result, list):
            # Fallback static cards
            return _fallback_cards(category, brand, color)
        cards = []
        for item in result:
            cards.append(
                SuggestionCard(
                    type=item.get("type", "info"),
                    title=item.get("title", ""),
                    description=item.get("description", ""),
                )
            )
        return cards


def _fallback_cards(category: str, brand: str, color: str) -> list[SuggestionCard]:
    cards = [
        SuggestionCard(
            type="lowest_price",
            title="🔍 比价全网最低价",
            description=f"搜索全网 {category} 最低价，帮你省钱",
        ),
        SuggestionCard(
            type="price_trend",
            title="📈 价格趋势分析",
            description=f"查看 {category} 近期价格波动，选择最佳入手时机",
        ),
    ]
    if brand:
        cards.insert(
            1,
            SuggestionCard(
                type="official_store",
                title="🏪 官方旗舰店",
                description=f"前往 {brand} 官方旗舰店，正品保障",
            ),
        )
    if color:
        cards.append(
            SuggestionCard(
                type="filter_color",
                title="🎨 按颜色筛选",
                description=f"筛选 {color} 款式的更多选择",
            )
        )
    cards.append(
        SuggestionCard(
            type="similar_style",
            title="✨ 相似风格推荐",
            description=f"发现更多类似 {category} 的热门单品",
        )
    )
    return cards
