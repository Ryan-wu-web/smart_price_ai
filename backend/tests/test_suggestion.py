import pytest
from unittest.mock import AsyncMock

from app.services.suggestion import SuggestionService
from app.models.schemas import SuggestionCard


@pytest.mark.asyncio
async def test_generate_cards_success():
    mock_llm = AsyncMock()
    mock_llm.chat_json.return_value = [
        {"type": "lowest_price", "title": "最低价", "description": "全网最低价"},
        {"type": "official_store", "title": "官方", "description": "官方旗舰店"},
    ]

    service = SuggestionService(llm_client=mock_llm)
    cards = await service.generate_cards(category="鞋", brand="Nike", color="白色")

    assert len(cards) == 2
    assert isinstance(cards[0], SuggestionCard)
    assert cards[0].type == "lowest_price"
    mock_llm.chat_json.assert_awaited_once()


@pytest.mark.asyncio
async def test_generate_cards_fallback():
    mock_llm = AsyncMock()
    mock_llm.chat_json.return_value = "not a list"

    service = SuggestionService(llm_client=mock_llm)
    cards = await service.generate_cards(category="鞋", brand="Nike", color="白色")

    assert len(cards) >= 3
    types = [c.type for c in cards]
    assert "lowest_price" in types
    assert "price_trend" in types
