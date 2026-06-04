"""
验证 chat_stream 从 LLM 返回的 JSON 片段中实时提取 reply 纯文本，
避免前端直接显示原始 JSON 字符串。
"""

import json
import pytest
from unittest.mock import AsyncMock

from app.services.chat import ChatService


@pytest.mark.asyncio
async def test_chat_stream_extracts_reply_text_from_json_chunks():
    """
    Bug 复现：LLM 流式返回 JSON 片段，如：
      chunk1: '{"reply": "Hello'
      chunk2: ' world", "action": "'
    
    修复后：后端应实时提取 reply 字段的累积内容，
    只把纯文本（新增部分）yield 给前端。
    """
    # 模拟 LLM 返回 JSON 片段（火山引擎 SSE 格式解析后的 content）
    json_chunks = [
        '{"reply": "耐克空军一号',
        '是经典鞋款',
        '", "action": "none", "action_data": {}}',
    ]

    async def fake_llm_stream(*args, **kwargs):
        for chunk in json_chunks:
            yield chunk

    mock_llm = AsyncMock()
    mock_llm.chat_stream = fake_llm_stream

    service = ChatService(llm_client=mock_llm)

    chunks = []
    async for chunk_json in service.chat_stream("test message"):
        chunk = json.loads(chunk_json)
        chunks.append(chunk)

    # 过滤出非 done 的 reply chunk
    reply_chunks = [c for c in chunks if not c.get("done")]

    # 🔴 修复前：reply_chunks 会包含原始 JSON 片段
    # ✅ 修复后：reply_chunks 应只包含提取出的纯文本片段
    combined_reply = "".join(c.get("reply", "") for c in reply_chunks)
    assert "耐克空军一号是经典鞋款" in combined_reply, (
        f"应提取 reply 纯文本，实际得到: {combined_reply!r}"
    )

    # 确保没有原始 JSON 结构泄漏到前端
    assert '{"reply"' not in combined_reply, (
        f"前端不应收到原始 JSON 结构！: {combined_reply!r}"
    )


@pytest.mark.asyncio
async def test_chat_stream_done_event_contains_full_data():
    """验证最后的 done 事件仍包含完整的 action/action_data/session_id。"""
    json_chunks = [
        '{"reply": "test", "action": "report", "action_data": {"report_type": "decision"}}',
    ]

    async def fake_llm_stream(*args, **kwargs):
        for chunk in json_chunks:
            yield chunk

    mock_llm = AsyncMock()
    mock_llm.chat_stream = fake_llm_stream

    service = ChatService(llm_client=mock_llm)

    done_events = []
    async for chunk_json in service.chat_stream("test"):
        chunk = json.loads(chunk_json)
        if chunk.get("done"):
            done_events.append(chunk)

    assert len(done_events) == 1
    assert done_events[0]["action"] == "report"
    assert done_events[0]["action_data"]["report_type"] == "decision"
