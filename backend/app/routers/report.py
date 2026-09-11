from fastapi import APIRouter, HTTPException
from app.models.schemas import ReportRequest, ReportResponse
from app.routers.knowledge import CatalogDependency
from app.services.report import ReportService

router = APIRouter(prefix="/api/v1", tags=["report"])


@router.post("/report", response_model=ReportResponse)
async def report(request: ReportRequest, catalog: CatalogDependency):
    try:
        return await ReportService(catalog).generate_report(
            request.product_name, request.best_choice, request.alternatives)
    except ValueError:
        raise HTTPException(status_code=422, detail="请选择有效的本地样例商品；客户端提供的名称和价格不能作为报告证据。") from None
