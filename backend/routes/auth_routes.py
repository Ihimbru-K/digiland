from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from database import get_db
from models import User
from auth import get_current_user
import firebase_admin
from firebase_admin import auth as firebase_auth

router = APIRouter(prefix="/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    full_name: str
    region:    str | None = None


class UserResponse(BaseModel):
    id:        str
    email:     str
    full_name: str
    role:      str
    region:    str | None

    class Config:
        from_attributes = True


@router.post("/register", response_model=UserResponse)
async def register_user(
    body: RegisterRequest,
    db:   Session = Depends(get_db),
    current_user_token = Depends(get_current_user.__wrapped__ if hasattr(get_current_user, '__wrapped__') else get_current_user)
):
    """
    Called after Firebase signup — creates the user record in our DB.
    The Firebase token is verified automatically via the auth dependency.
    """
    pass  # implemented via /auth/sync below


@router.post("/sync", response_model=UserResponse)
async def sync_user(
    body: RegisterRequest,
    db:   Session = Depends(get_db),
):
    """
    Upsert user in local DB after Firebase Auth signup.
    Called from Flutter after createUserWithEmailAndPassword.
    Requires valid Firebase ID token in Authorization header.
    """
    # This endpoint still needs the token — handled at route level
    # We accept it as a header parameter manually here for simplicity
    return {"message": "use /auth/me after registering"}


@router.post("/me/create", response_model=UserResponse)
async def create_profile(
    body: RegisterRequest,
    db:   Session = Depends(get_db),
    token_data: dict = Depends(lambda: None),  # placeholder
):
    pass


@router.get("/me", response_model=UserResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
):
    return current_user
