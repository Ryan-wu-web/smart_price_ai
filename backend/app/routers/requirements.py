"""Additive, stateless requirements endpoint; existing chat remains compatible."""
from fastapi import APIRouter, HTTPException

from app.models.requirements import RequirementParseRequest, RequirementParseResponse
from app.services.requirements import RequirementParser, RequirementUpdateError

router = APIRouter(prefix="/api/v1/requirements", tags=["requirements"])


@router.post("/parse", response_model=RequirementParseResponse)
def parse_requirements(body: RequirementParseRequest):
    try:
        return RequirementParser().parse(body)
    except RequirementUpdateError as exc:
        raise HTTPException(status_code=409, detail={"code": exc.code, "message": str(exc)}) from None
