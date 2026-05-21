import uuid
from typing import Any

from app.core.llm_client import LLMClient
from app.core.prompt_engine import PromptEngine


class ChatService:
    def __init__(self, llm_client: LLMClient | None = None):
        self.llm_client = llm_client or LLMClient()
        self._sessions: dict[str, list[dict[str, Any]]] = {}

    async def chat(
        self,
        message: str,
        session_id: str | None = None,
        current_product: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        if not session_id:
            session_id = str(uuid.uuid4())
        context = self._sessions.get(session_id, [])
        context.append({"role": "user", "content": message})
        prompt = PromptEngine.chat_reply(message, context, current_product)
        messages = [{"role": "user", "content": prompt}]
        result = await self.llm_client.chat_json(messages)
        reply = result.get("reply", "")
        action = result.get("action", "none")
        action_data = result.get("action_data", {})
        if not isinstance(action_data, dict):
            action_data = {}
        context.append({"role": "assistant", "content": reply})
        self._sessions[session_id] = context
        return {
            "reply": reply,
            "action": action,
            "action_data": action_data,
            "session_id": session_id,
        }
