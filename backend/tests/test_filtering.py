import pytest
from unittest.mock import AsyncMock

from app.services.filtering import FilteringService


@pytest.mark.asyncio
async def test_parse_filter_success():
    mock_llm = AsyncMock()
    mock_llm.chat_json.return_value = {
        "price_max": 500,
        "color": "红色",
        "rating_min": 4.5,
    }

    service = FilteringService(llm_client=mock_llm)
    result = await service.parse_filter("我想买500元以下的红色商品，评分4.5以上")

    assert result["price_max"] == 500
    assert result["color"] == "红色"
    assert result["rating_min"] == 4.5
    mock_llm.chat_json.assert_awaited_once()


@pytest.mark.asyncio
async def test_parse_filter_invalid_response():
    mock_llm = AsyncMock()
    mock_llm.chat_json.return_value = "not a dict"

    service = FilteringService(llm_client=mock_llm)
    result = await service.parse_filter("随便说说")

    assert result == {}
