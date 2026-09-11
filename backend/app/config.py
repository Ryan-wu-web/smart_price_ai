import logging

from pydantic import Field
from pydantic_settings import BaseSettings

logger = logging.getLogger(__name__)


class Settings(BaseSettings):
    app_name: str = "Smart Price AI"
    debug: bool = False
    database_url: str = ""
    redis_url: str = ""
    volcengine_api_key: str = ""
    volcengine_endpoint: str = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    volcengine_model: str = ""

    model_connect_timeout_seconds: float = Field(default=10, gt=0, le=120)
    model_read_timeout_seconds: float = Field(default=60, gt=0, le=300)
    model_write_timeout_seconds: float = Field(default=30, gt=0, le=120)
    model_pool_timeout_seconds: float = Field(default=10, gt=0, le=120)
    model_max_connections: int = Field(default=20, ge=1, le=100)
    model_json_repair_attempts: int = Field(default=1, ge=0, le=2)

    class Config:
        protected_namespaces = ("settings_",)
        env_file = ".env"


settings = Settings()

if not settings.volcengine_api_key:
    logger.warning("volcengine_api_key is empty; model calls require configuration. Local data endpoints remain available.")
