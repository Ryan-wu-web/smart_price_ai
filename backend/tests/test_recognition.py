import os
import shutil

import pytest
from unittest.mock import AsyncMock

from app.services.recognition import RecognitionService, CACHE_DIR
from app.models.schemas import RecognizeResponse


@pytest.fixture(autouse=True)
def clear_recognition_cache():
    """每个测试前清除识别缓存，避免测试间互相影响。"""
    shutil.rmtree(CACHE_DIR, ignore_errors=True)
    yield


@pytest.mark.asyncio
async def test_recognize_single_call_success():
    """主路径：单次调用直接返回结果。"""
    mock_vlm = AsyncMock()
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
    mock_llm.chat_json.assert_awaited_once()
    mock_vlm.describe_image.assert_not_awaited()


@pytest.mark.asyncio
async def test_recognize_fallback_to_two_stage():
    """Fallback：单次调用失败后降级到两阶段。"""
    mock_vlm = AsyncMock()
    mock_vlm.describe_image.return_value = "这是一双白色的 Nike Air Max 运动鞋"
    mock_llm = AsyncMock()
    # 第一次调用失败，第二次成功
    mock_llm.chat_json.side_effect = [
        Exception("parse error"),  # 主路径失败
        {
            "name": "Nike Air Max 90",
            "brand": "Nike",
            "category": "鞋",
            "color": "白色",
            "material": "网面",
            "style": "运动休闲",
        },
    ]

    service = RecognitionService(vlm_client=mock_vlm, llm_client=mock_llm)
    result = await service.recognize("fake_base64_fallback")

    assert isinstance(result, RecognizeResponse)
    assert result.name == "Nike Air Max 90"
    mock_vlm.describe_image.assert_awaited_once_with("fake_base64_fallback")
    assert mock_llm.chat_json.await_count == 2
