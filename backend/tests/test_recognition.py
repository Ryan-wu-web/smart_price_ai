import pytest
from unittest.mock import AsyncMock, patch

from app.services.recognition import RecognitionService
from app.models.schemas import RecognizeResponse


@pytest.mark.asyncio
async def test_recognize_success():
    mock_vlm = AsyncMock()
    mock_vlm.describe_image.return_value = "这是一双白色的 Nike Air Max 运动鞋"
    mock_llm = AsyncMock()
    mock_llm.chat_json.return_value = {
        "name": "Nike Air Max 90",
        "brand": "Nike",
        "category": "鞋",
        "color": "白色",
        "material": "网面",
        "style": "运动休闲",
    }

    service = RecognitionService(vlm_client=mock_vlm, llm_client=mock_llm)
    result = await service.recognize("fake_base64")

    assert isinstance(result, RecognizeResponse)
    assert result.name == "Nike Air Max 90"
    assert result.brand == "Nike"
    assert result.category == "鞋"
    mock_vlm.describe_image.assert_awaited_once_with("fake_base64")
    mock_llm.chat_json.assert_awaited_once()
