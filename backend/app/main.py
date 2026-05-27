import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.middleware.error_handler import global_exception_handler
from app.routers import recognize, suggest, compare, filter, trend, report, chat

app = FastAPI(
    title=settings.app_name,
    description="AI 拍照识物与智能比价购物助手",
    version="1.0.0",
)

# CORS: 生产环境应限制为明确的前端域名
_origins = ["*"] if settings.debug else (
    os.environ.get("ALLOWED_ORIGINS", "").split(",") if os.environ.get("ALLOWED_ORIGINS") else []
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=not settings.debug,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

app.add_exception_handler(Exception, global_exception_handler)

app.include_router(recognize.router)
app.include_router(suggest.router)
app.include_router(compare.router)
app.include_router(filter.router)
app.include_router(trend.router)
app.include_router(report.router)
app.include_router(chat.router)


@app.get("/health")
def health_check():
    return {"status": "ok", "app": settings.app_name}
