"""Small streaming boundaries: typed app events and incremental JSON reply text."""
import json
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, TypeAdapter

from app.core.base_api_client import ModelOutputError
from app.models.schemas import ChatResponse, SessionId


class EventBase(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version: Literal[1] = 1
    session_id: SessionId
    seq: int = Field(ge=1)


class TextEvent(EventBase):
    type: Literal["delta"] = "delta"
    reply: str = Field(min_length=1, max_length=16000)


class StatusEvent(EventBase):
    type: Literal["status"] = "status"
    node: Literal["context", "model", "validation", "save"]
    status: Literal["running"] = "running"
    message: str


class ResultEvent(EventBase, ChatResponse):
    type: Literal["result"] = "result"
    done: Literal[True] = True


class ErrorEvent(EventBase):
    type: Literal["error"] = "error"
    code: str
    error: str
    done: Literal[True] = True
    reply: Literal[""] = ""
    action: Literal["none"] = "none"
    action_data: dict = Field(default_factory=dict)


class EndEvent(EventBase):
    type: Literal["end"] = "end"
    success: bool


ChatEvent = Annotated[TextEvent | StatusEvent | ResultEvent | ErrorEvent | EndEvent,
                      Field(discriminator="type")]
EVENT_ADAPTER = TypeAdapter(ChatEvent)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


class ReplyDecoder:
    """Lex just enough JSON to emit the top-level reply, never nested lookalikes.

    Full JSON and schema validation is still mandatory before saving. Escape and
    Unicode sequences can span chunks; lone surrogates are never sent to UTF-8.
    """
    def __init__(self):
        self.depth = 0
        self.in_string = False
        self.kind = "other"
        self.key = ""
        self.key_token = ""
        self.expect_key = False
        self.expect_value = False
        self.escaped = False
        self.unicode_digits = None
        self.high_surrogate = None
        self.reply_seen = False
        self.text = ""

    def _char(self, char):
        code = ord(char)
        if self.high_surrogate is not None:
            if not 0xDC00 <= code <= 0xDFFF:
                raise ValueError("Unpaired surrogate")
            char = chr(0x10000 + ((self.high_surrogate - 0xD800) << 10) + code - 0xDC00)
            self.high_surrogate = None
        elif 0xD800 <= code <= 0xDBFF:
            self.high_surrogate = code
            return ""
        elif 0xDC00 <= code <= 0xDFFF:
            raise ValueError("Unpaired surrogate")
        return char

    def feed(self, chunk: str) -> str:
        output = []
        try:
            for char in chunk:
                if self.in_string:
                    if self.kind == "key":
                        self.key_token += char
                    if self.unicode_digits is not None:
                        if char not in "0123456789abcdefABCDEF":
                            raise ValueError("Invalid Unicode escape")
                        self.unicode_digits += char
                        if len(self.unicode_digits) == 4:
                            if self.kind == "reply":
                                output.append(self._char(chr(int(self.unicode_digits, 16))))
                            self.unicode_digits = None
                        continue
                    if self.escaped:
                        self.escaped = False
                        if char == "u":
                            self.unicode_digits = ""
                        else:
                            value = {'"': '"', "\\": "\\", "/": "/", "b": "\b",
                                     "f": "\f", "n": "\n", "r": "\r", "t": "\t"}[char]
                            if self.kind == "reply":
                                output.append(self._char(value))
                        continue
                    if char == "\\":
                        self.escaped = True
                    elif char == '"':
                        self.in_string = False
                        if self.kind == "key":
                            self.key = json.loads('"' + self.key_token)
                            self.expect_key = False
                        if self.kind == "reply" and self.high_surrogate is not None:
                            raise ValueError("Unpaired surrogate")
                    elif ord(char) < 32:
                        raise ValueError("Unescaped control character")
                    elif self.kind == "reply":
                        output.append(self._char(char))
                    continue
                if char == '"':
                    self.in_string = True
                    self.key_token = ""
                    self.kind = "key" if self.depth == 1 and self.expect_key else "other"
                    if self.depth == 1 and self.expect_value and self.key == "reply":
                        if self.reply_seen:
                            raise ValueError("Duplicate reply")
                        self.reply_seen = True
                        self.kind = "reply"
                    self.expect_value = False
                elif char in "{[":
                    self.depth += 1
                    self.expect_key = char == "{" and self.depth == 1
                    self.expect_value = False
                elif char in "}]":
                    self.depth -= 1
                elif char == "," and self.depth == 1:
                    self.expect_key = True
                    self.expect_value = False
                elif char == ":" and self.depth == 1:
                    self.expect_value = True
                elif not char.isspace():
                    self.expect_value = False
            delta = "".join(output)
            self.text += delta
            if len(self.text) > 16000:
                raise ValueError("Reply limit")
            return delta
        except (ValueError, KeyError):
            raise ModelOutputError("回复格式不符合要求，本轮未保存，请重试。") from None
