import pytest
from unittest.mock import AsyncMock

from app.services.chat import ChatService


@pytest.mark.asyncio
async def test_chat_new_session():
    mock_llm = AsyncMock()
    mock_llm.chat_json.return_value = {
        "reply": "你好，有什么可以帮你的？",
        "action": "none",
        "action_data": {},
    }

    service = ChatService(llm_client=mock_llm)
    result = await service.chat(message="你好")

    assert "reply" in result
    assert result["reply"] == "你好，有什么可以帮你的？"
    assert result["action"] == "none"
    assert "session_id" in result
    assert result["session_id"] is not None


@pytest.mark.asyncio
async def test_chat_existing_session():
    mock_llm = AsyncMock()
    mock_llm.chat_json.return_value = {
        "reply": "好的",
        "action": "compare",
        "action_data": {"category": "鞋"},
    }

    service = ChatService(llm_client=mock_llm)
    first = await service.chat(message="我想买鞋")
    sid = first["session_id"]
    second = await service.chat(message="有什么推荐", session_id=sid)

    assert second["session_id"] == sid
    assert second["action"] == "compare"
    assert second["action_data"]["category"] == "鞋"
