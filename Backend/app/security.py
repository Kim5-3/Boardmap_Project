from datetime import datetime, timedelta, timezone
import jwt
from pwdlib import PasswordHash
from .config import settings

password_hash = PasswordHash.recommended()
ALGORITHM = "HS256"


def hash_password(password: str) -> str:
    return password_hash.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    return password_hash.verify(password, hashed)


def create_access_token(user_id: int) -> str:
    if len(settings.jwt_secret_key) < 32:
        raise RuntimeError("Set JWT_SECRET_KEY to a random value of at least 32 characters")
    now = datetime.now(timezone.utc)
    return jwt.encode({"sub": str(user_id), "iat": now, "exp": now + timedelta(minutes=settings.access_token_minutes)}, settings.jwt_secret_key, algorithm=ALGORITHM)


def decode_access_token(token: str) -> int:
    payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[ALGORITHM])
    return int(payload["sub"])