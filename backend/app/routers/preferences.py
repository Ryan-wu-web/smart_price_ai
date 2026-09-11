"""Local single-user preference management. Not a public multi-tenant API."""
from fastapi import APIRouter, HTTPException
from app.models.preferences import PreferenceProfile, PreferenceUpdate
from app.services.preferences import PreferenceStore
from app.services.sessions import SessionError

router = APIRouter(prefix="/api/v1/preferences", tags=["preferences"])

@router.get("", response_model=PreferenceProfile)
def read_preferences():
    try:
        return PreferenceStore().read()
    except SessionError as exc:
        raise HTTPException(exc.status_code, str(exc)) from None

@router.post("", response_model=PreferenceProfile)
def replace_preferences(request: PreferenceUpdate):
    """Confirmed full replacement also supports edit/delete; [] clears preferences only."""
    try:
        return PreferenceStore().replace(request)
    except SessionError as exc:
        raise HTTPException(exc.status_code, str(exc)) from None
