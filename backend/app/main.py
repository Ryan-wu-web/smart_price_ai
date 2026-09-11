import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.core.base_api_client import create_http_client
from app.middleware.error_handler import global_exception_handler
from app.routers import recognize, suggest, compare, filter, trend, report, chat, knowledge, requirements, recommendations, preferences
from app.services.knowledge import CatalogUnavailable, ProductCatalog
from app.services.retrieval import ProductRetriever, RetrievalUnavailable

@asynccontextmanager
async def lifespan(app: FastAPI):
    # One pool per app/worker; no import-time sockets or global cross-loop client.
    async with create_http_client() as client:
        app.state.model_http = client
        try:
            app.state.product_catalog = ProductCatalog()
        except CatalogUnavailable:
            # Catalog endpoints fail explicitly; recognition/chat can still run.
            app.state.product_catalog = None
        app.state.product_retriever = None
        if app.state.product_catalog is not None:
            try:
                app.state.product_retriever = ProductRetriever(app.state.product_catalog)
            except RetrievalUnavailable:
                pass  # Browsing and model routes remain usable if the optional index fails.
        yield


app = FastAPI(
    lifespan=lifespan,
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
app.include_router(knowledge.router)
app.include_router(requirements.router)
app.include_router(recommendations.router)
app.include_router(preferences.router)


@app.get("/health")
def health_check():
    return {"status": "ok", "app": settings.app_name}
