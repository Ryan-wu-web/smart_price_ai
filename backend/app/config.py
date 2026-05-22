import logging

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

    class Config:
        env_file = ".env"


settings = Settings()

if not settings.volcengine_api_key:
    logger.warning("volcengine_api_key is empty; LLM/VLM calls will fail unless mock mode is used.")
