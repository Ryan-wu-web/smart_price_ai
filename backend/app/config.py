from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_name: str = "Smart Price AI"
    debug: bool = True
    database_url: str = "postgresql://user:password@localhost:5432/smartprice"
    redis_url: str = "redis://localhost:6379/0"
    volcengine_api_key: str = ""
    volcengine_endpoint: str = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    volcengine_model: str = "ep-20260514111211-cd94c"

    class Config:
        env_file = ".env"

settings = Settings()
