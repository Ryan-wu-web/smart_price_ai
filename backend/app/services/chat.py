import json
import os
import uuid
from typing import Any

from app.core.llm_client import LLMClient
from app.core.prompt_engine import PromptEngine

SESSION_DIR = "data/sessions"
SUMMARY_THRESHOLD = 8  # 4轮对话 = 8条消息


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

        # 加载已有会话（内存优先，否则读文件）
        context = self._sessions.get(session_id)
        if context is None:
            context = self._load_session(session_id)

        context.append({"role": "user", "content": message})

        # 对话摘要：超过阈值时生成摘要
        if len(context) > SUMMARY_THRESHOLD:
            context = await self._summarize_and_compact(context)

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
        self._save_session(session_id, context)

        return {
            "reply": reply,
            "action": action,
            "action_data": action_data,
            "session_id": session_id,
        }

    async def _summarize_and_compact(
        self, context: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        """生成摘要并压缩历史对话。"""
        try:
            history_text = "\n".join(
                [
                    f"{'用户' if c['role'] == 'user' else '助手'}: {c['content']}"
                    for c in context[:-6]
                ]
            )
            summary_prompt = (
                "请对以下购物对话历史进行摘要，保留关键信息（用户关注的商品、"
                "核心需求、已做出的决策），控制在 100 字以内。\n\n"
                f"{history_text}\n\n"
                "只输出摘要内容，不要添加任何解释。"
            )
            summary_messages = [{"role": "user", "content": summary_prompt}]
            summary_result = await self.llm_client.chat_json(
                summary_messages, temperature=0.3, max_tokens=256
            )
            summary = summary_result.get("reply", summary_result.get("summary", ""))

            compacted = [
                {
                    "role": "system",
                    "content": f"历史对话摘要：{summary}",
                },
                *context[-6:],
            ]
            return compacted
        except Exception:
            # 摘要失败则只保留最近6条
            return context[-6:]

    def _save_session(self, session_id: str, context: list[dict[str, Any]]) -> None:
        try:
            os.makedirs(SESSION_DIR, exist_ok=True)
            filepath = os.path.join(SESSION_DIR, f"{session_id}.json")
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(context, f, ensure_ascii=False)
        except Exception:
            pass

    async def chat_stream(
        self,
        message: str,
        session_id: str | None = None,
        current_product: dict[str, Any] | None = None,
    ):
        """
        流式聊天：yield JSON chunk。
        前半段 yield 逐字 reply，最后 yield 包含完整 action/action_data 的 done 标记。
        """
        if not session_id:
            session_id = str(uuid.uuid4())

        context = self._sessions.get(session_id)
        if context is None:
            context = self._load_session(session_id)

        context.append({"role": "user", "content": message})

        if len(context) > SUMMARY_THRESHOLD:
            context = await self._summarize_and_compact(context)

        prompt = PromptEngine.chat_reply(message, context, current_product)
        messages = [{"role": "user", "content": prompt}]

        # 收集完整回复，用于后续解析 action/action_data
        full_reply = ""
        async for chunk in self.llm_client.chat_stream(messages):
            full_reply += chunk
            yield json.dumps(
                {"reply": chunk, "session_id": session_id},
                ensure_ascii=False,
            )

        # 尝试将完整回复解析为 JSON
        reply_text = ""
        action = "none"
        action_data = {}
        try:
            parsed = json.loads(full_reply)
            reply_text = parsed.get("reply", full_reply)
            action = parsed.get("action", "none")
            action_data = parsed.get("action_data", {})
        except json.JSONDecodeError:
            reply_text = full_reply

        if not isinstance(action_data, dict):
            action_data = {}

        context.append({"role": "assistant", "content": reply_text})
        self._sessions[session_id] = context
        self._save_session(session_id, context)

        # 发送最终 done 事件，包含完整的 action/action_data
        yield json.dumps(
            {
                "reply": reply_text,
                "action": action,
                "action_data": action_data,
                "session_id": session_id,
                "done": True,
            },
            ensure_ascii=False,
        )

    def _load_session(self, session_id: str) -> list[dict[str, Any]]:
        try:
            filepath = os.path.join(SESSION_DIR, f"{session_id}.json")
            if os.path.exists(filepath):
                with open(filepath, "r", encoding="utf-8") as f:
                    return json.load(f)
        except Exception:
            pass
        return []
