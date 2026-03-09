import firebase_admin
from firebase_admin import credentials, auth as firebase_auth
from fastapi import HTTPException, Security, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from database import get_db
from models import User
from config import get_settings
import os
import json

settings = get_settings()
security = HTTPBearer()

if not firebase_admin._apps:
    sa_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    if sa_json:
        cred = credentials.Certificate(json.loads(sa_json))
    elif os.path.exists(settings.firebase_service_account_path):
        cred = credentials.Certificate(settings.firebase_service_account_path)
    else:
        raise Exception("No Firebase credentials found")
    firebase_admin.initialize_app(cred)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(security),
    db: Session = Depends(get_db)
) -> User:
    token = credentials.credentials
    try:
        decoded = firebase_auth.verify_id_token(token)
        uid = decoded["uid"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user = db.query(User).filter(User.firebase_uid == uid).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not registered in LandVault")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account suspended")
    return user


async def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user




# import firebase_admin
# from firebase_admin import credentials, auth as firebase_auth
# from fastapi import HTTPException, Security, Depends
# from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
# from sqlalchemy.orm import Session
# from database import get_db
# from models import User
# from config import get_settings
# import os

# settings = get_settings()
# security = HTTPBearer()

# # Initialize Firebase Admin SDK once
# if not firebase_admin._apps:
#     if os.path.exists(settings.firebase_service_account_path):
#         cred = credentials.Certificate(settings.firebase_service_account_path)
#         firebase_admin.initialize_app(cred)
#     else:
#         # Dev fallback — set GOOGLE_APPLICATION_CREDENTIALS env var
#         firebase_admin.initialize_app()


# async def get_current_user(
#     credentials: HTTPAuthorizationCredentials = Security(security),
#     db: Session = Depends(get_db)
# ) -> User:
#     token = credentials.credentials
#     try:
#         decoded = firebase_auth.verify_id_token(token)
#         uid = decoded["uid"]
#     except Exception:
#         raise HTTPException(status_code=401, detail="Invalid or expired token")

#     user = db.query(User).filter(User.firebase_uid == uid).first()
#     if not user:
#         raise HTTPException(status_code=404, detail="User not registered in LandVault")
#     if not user.is_active:
#         raise HTTPException(status_code=403, detail="Account suspended")
#     return user


# async def require_admin(current_user: User = Depends(get_current_user)) -> User:
#     if current_user.role != "admin":
#         raise HTTPException(status_code=403, detail="Admin access required")
#     return current_user
