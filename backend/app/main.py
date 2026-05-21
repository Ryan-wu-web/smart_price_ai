from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import recognize, suggest, compare, filter, trend, report, chat

app = FastAPI(
    title=settings.app_name,
    description="AI 拍照识物与智能比价购物助手",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
