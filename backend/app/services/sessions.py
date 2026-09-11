"""Versioned local sessions. Run one worker until a shared store is introduced."""
import asyncio
from contextlib import asynccontextmanager
import json
import logging
import os
from pathlib import Path
import tempfile
from typing import Literal
from weakref import WeakValueDictionary

from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator

from app.models.schemas import ChatProduct, validate_session_id
from app.models.workflow import WorkflowState

logger = logging.getLogger(__name__)
MAX_SESSION_BYTES = 2_000_000
MAX_PROMPT_CHARS = 48_000
SESSION_LOCK_TIMEOUT = 30
# Weak entries disappear when no caller is using/waiting on the session.
_LOCKS: WeakValueDictionary = WeakValueDictionary()


class SessionError(ValueError):
    def __init__(self, message: str, code: str = "SESSION_UNAVAILABLE", status_code: int = 503):
        super().__init__(message)
        self.code = code
        self.status_code = status_code


class SessionMessage(BaseModel):
    model_config = ConfigDict(extra="forbid")
    role: Literal["user", "assistant", "system"]
    content: str = Field(min_length=1, max_length=24000)


class SessionState(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version: Literal[2] = 2
    messages: list[SessionMessage] = Field(default_factory=list, max_length=500)
    summary: str = Field(default="", max_length=6000)
    summarized_count: int = Field(default=0, ge=0, strict=True)
    current_product: ChatProduct | None = None
    workflow: WorkflowState | None = None

    @model_validator(mode="after")
    def valid_summary_cursor(self):
        if self.summarized_count > len(self.messages) or bool(self.summary) != bool(self.summarized_count):
            raise ValueError("Invalid summary cursor")
        return self


class SessionStore:
    def __init__(self, directory: str):
        self.root = Path(directory).resolve()

    def path(self, session_id: str) -> Path:
        validate_session_id(session_id)
        path = self.root / f"{session_id}.json"
        # Reject a pre-existing symlink rather than following it on read/write.
        if path.is_symlink() or path.resolve().parent != self.root:
            raise SessionError("会话存储路径无效，请重新开始对话。", "SESSION_PATH_INVALID", 409)
        return path

    @asynccontextmanager
    async def turn(self, session_id: str):
        key = (asyncio.get_running_loop(), os.path.normcase(str(self.path(session_id))))
        lock = _LOCKS.get(key)
        if lock is None:
            lock = asyncio.Lock()
            _LOCKS[key] = lock
        try:
            await asyncio.wait_for(lock.acquire(), timeout=SESSION_LOCK_TIMEOUT)
        except TimeoutError:
            raise SessionError("上一条消息仍在处理中，请稍后再试。", "SESSION_BUSY", 409) from None
        try:
            yield
        finally:
            lock.release()

    def load(self, session_id: str) -> SessionState:
        path = self.path(session_id)
        try:
            with path.open("rb") as handle:
                payload = handle.read(MAX_SESSION_BYTES + 1)
            if len(payload) > MAX_SESSION_BYTES:
                raise SessionError("会话过长，请新建对话；原历史未删除。", "SESSION_TOO_LARGE", 413)
            # A legacy list is validated before migration, never silently cleared.
            data = json.loads(payload)
            if isinstance(data, list):
                data = {"messages": data}
            elif not isinstance(data, dict) or data.get("version") != 2:
                raise ValueError("Unsupported session version")
            state = SessionState.model_validate(data)
            if state.workflow is not None and state.workflow.session_id != session_id:
                raise ValueError("Workflow session mismatch")
            return state
        except FileNotFoundError:
            return SessionState()
        except (ValueError, UnicodeError, ValidationError) as exc:
            if isinstance(exc, SessionError):
                raise
            logger.warning("session_read_failed code=SESSION_CORRUPT")
            raise SessionError("历史会话无法读取，原文件已保留，请新建对话。", "SESSION_CORRUPT", 409) from None
        except OSError:
            logger.warning("session_read_failed code=SESSION_UNAVAILABLE")
            raise SessionError("暂时无法读取会话，请稍后重试。") from None

    def save(self, session_id: str, state: SessionState) -> None:
        path = self.path(session_id)
        temporary: Path | None = None
        try:
            # Revalidate mutable state, including final output, before any write.
            checked = SessionState.model_validate(state.model_dump())
            if checked.workflow is not None and checked.workflow.session_id != session_id:
                raise SessionError("会话状态不一致，本轮未保存。", "SESSION_CORRUPT", 409)
            # Null is an explicit unknown catalog fact, not an absent field.
            # Dropping it makes required nullable parameters impossible to reload.
            payload = checked.model_dump_json().encode("utf-8")
            SessionState.model_validate_json(payload)
            if len(payload) > MAX_SESSION_BYTES:
                raise SessionError("会话过长，请新建对话；原历史未删除。", "SESSION_TOO_LARGE", 413)
            self.root.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=self.root, prefix=".session-", suffix=".tmp", delete=False) as handle:
                temporary = Path(handle.name)
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, path)
        except (OSError, ValidationError):
            logger.warning("session_write_failed code=SESSION_UNAVAILABLE")
            raise SessionError("回复未能保存，请稍后重试；原历史未修改。") from None
        finally:
            if temporary is not None:
                try:
                    temporary.unlink(missing_ok=True)
                except OSError:
                    logger.warning("session_temporary_cleanup_failed")
