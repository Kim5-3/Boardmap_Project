from contextlib import asynccontextmanager
from collections import defaultdict, deque
from datetime import date, datetime, time as datetime_time, timedelta, timezone
from decimal import Decimal
import logging
from pathlib import Path
import re
from threading import Lock
import time
from uuid import uuid4
from fastapi import Depends, FastAPI, File, Form, HTTPException, Query, Request, Response, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import String, func, literal, or_, select, text, union_all
from sqlalchemy.exc import IntegrityError, OperationalError, ProgrammingError
from sqlalchemy.orm import Session
from .config import settings
from .database import Base, engine, get_db
from .dependencies import admin_user, current_user, owner_user
from .models import BoardingHouse, Favorite, HouseImage, Inquiry, IssueReport, IssueReportHistory, IssueReportMessage, ListingModerationEvent, Notification, User
from .recommendation_engine import rank_with_knn
from .schemas import AdminActivityPageOut, AdminSummary, AdminUserOut, HouseIn, HouseOut, HousePatch, InquiryIn, InquiryOut, InquiryResponseIn, IssueReportDetailOut, IssueReportMessageIn, IssueReportMessageOut, IssueReportOut, IssueReportPageOut, IssueReportStatistics, IssueReportStatusIn, ListingStatusIn, LoginIn, NotificationOut, PasswordChange, RecommendationOut, RegisterIn, TokenOut, UserOut, UserPatch
from .security import create_access_token, hash_password, verify_password


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.auto_create_tables:
        Base.metadata.create_all(bind=engine)
    settings.upload_dir.mkdir(parents=True, exist_ok=True)
    yield


app = FastAPI(title="BoardMap API", version="1.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_origin_regex=settings.allowed_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount("/uploads", StaticFiles(directory=str(settings.upload_dir), check_dir=False), name="uploads")
logger = logging.getLogger(__name__)
PUBLIC_LISTING_STATUSES = ("Active", "Approved")
_SEARCH_STOP_WORDS = {"bh", "boarding", "house", "houses", "the", "for", "near"}


def listing_search_terms(value: str) -> list[str]:
    terms = re.findall(r"[a-z0-9]+", value.casefold())
    return [
        term[:-1] if len(term) > 4 and term.endswith("s") else term
        for term in terms
        if term not in _SEARCH_STOP_WORDS
    ]


_login_attempts: dict[tuple[str, str], deque[float]] = defaultdict(deque)
_rate_limit_lock = Lock()


def enforce_rate_limit(request: Request, bucket: str, limit: int) -> None:
    now = time.monotonic()
    client_ip = request.client.host if request.client else "unknown"
    key = (bucket, client_ip)
    with _rate_limit_lock:
        attempts = _login_attempts[key]
        while attempts and now - attempts[0] >= 60:
            attempts.popleft()
        if len(attempts) >= limit:
            raise HTTPException(status_code=429, detail="Too many attempts. Try again in a minute.", headers={"Retry-After": "60"})
        attempts.append(now)


def house_out(row: BoardingHouse) -> HouseOut:
    return HouseOut(id=row.id, owner_id=row.owner_id, name=row.name, location=row.location, description=row.description,
                    price=row.price, available_rooms=row.available_rooms, room_type=row.room_type,
                    amenities=[x.strip() for x in row.amenities.split(",") if x.strip()],
                    rules=row.rules, curfew_details=row.curfew_details,
                    safety_features=[x.strip() for x in row.safety_features.split(",") if x.strip()],
                    utility_details=[x.strip() for x in row.utility_details.split(",") if x.strip()],
                    gender_policy=row.gender_policy, deposit_terms=row.deposit_terms,
                    campus_distance_km=float(row.campus_distance_km) if row.campus_distance_km is not None else None,
                    status=row.status,
                    rejection_reason=row.rejection_reason,
                    latitude=float(row.latitude) if row.latitude is not None else None,
                    longitude=float(row.longitude) if row.longitude is not None else None, created_at=row.created_at,
                    image_urls=[f"/uploads/{image.relative_path}" for image in row.images])


def inquiry_out(row: Inquiry) -> InquiryOut:
    return InquiryOut(
        id=row.id,
        boarding_house_id=row.boarding_house_id,
        house_name=row.boarding_house.name,
        renter_id=row.renter_id,
        renter_name=row.renter.full_name,
        renter_email=row.renter.email,
        message=row.message,
        response=row.response,
        status=row.status,
        created_at=row.created_at,
    )


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def readiness(db: Session = Depends(get_db)):
    """Report ready only when the configured PostgreSQL connection responds."""
    db.execute(text("SELECT 1"))
    return {"status": "ok", "database": "ok"}


@app.exception_handler(OperationalError)
def database_connection_error(request: Request, exc: OperationalError):
    # Avoid logging driver details because connection errors can contain configuration data.
    logger.error("Database operation failed for %s %s (%s)", request.method, request.url.path,
                 type(exc.orig).__name__ if exc.orig is not None else "OperationalError")
    return JSONResponse(status_code=503, content={
        "detail": "Database unavailable. Check PostgreSQL connectivity and application-role credentials."
    })


@app.exception_handler(ProgrammingError)
def database_schema_error(request: Request, exc: ProgrammingError):
    # SQLSTATE is safe to log; driver messages may contain SQL or user input.
    original = exc.orig
    sqlstate = getattr(original, "sqlstate", None) or getattr(original, "pgcode", None)
    logger.error("Database query failed for %s %s (SQLSTATE %s)",
                 request.method, request.url.path, sqlstate or "unknown")

    if sqlstate == "42P01":
        return JSONResponse(status_code=503, content={
            "detail": "Database schema is not initialized. Apply the reviewed Alembic migrations."
        })
    if sqlstate == "42501":
        return JSONResponse(status_code=503, content={
            "detail": "The application database role lacks required table permissions."
        })
    return JSONResponse(status_code=500, content={"detail": "Internal Server Error"})


@app.post("/api/v1/auth/register", response_model=TokenOut, status_code=201,
          responses={503: {"description": "PostgreSQL unavailable, schema uninitialized, or role permissions missing"}})
def register(data: RegisterIn, request: Request, db: Session = Depends(get_db)):
    enforce_rate_limit(request, "register", 10)
    email = str(data.email).lower()
    username = data.username
    if username is None:
        base = re.sub(r"[^A-Za-z0-9_.-]", "", email.split("@", 1)[0])[:30] or "account"
        if len(base) < 3:
            base = f"user_{base}"
        username = base
        if db.scalar(select(User.id).where(User.username == username)):
            for _ in range(5):
                username = f"{base[:30]}.{uuid4().hex[:8]}"
                if db.scalar(select(User.id).where(User.username == username)) is None:
                    break
            else:
                raise HTTPException(status_code=503, detail="Could not create a unique account identifier. Please retry.")
    if db.scalar(select(User).where(or_(User.email == email, User.username == username))):
        raise HTTPException(status_code=409, detail="Email or username is already registered")
    user = User(full_name=data.full_name.strip(), username=username, email=email,
                contact_number=data.contact_number,
                password_hash=hash_password(data.password), role=data.role)
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Email or username is already registered") from None
    db.refresh(user)
    return TokenOut(access_token=create_access_token(user.id), user=user)


@app.post("/api/v1/auth/login", response_model=TokenOut)
def login(data: LoginIn, request: Request, db: Session = Depends(get_db)):
    enforce_rate_limit(request, "login", 20)
    identifier = data.identifier.strip().lower()
    user = db.scalar(select(User).where(or_(User.email == identifier, User.username == identifier)))
    if user is None or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email/username or password")
    return TokenOut(access_token=create_access_token(user.id), user=user)


@app.get("/api/v1/auth/me", response_model=UserOut)
@app.get("/api/v1/users/me", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return user


@app.patch("/api/v1/users/me", response_model=UserOut)
def update_me(data: UserPatch, user: User = Depends(current_user), db: Session = Depends(get_db)):
    changes = data.model_dump(exclude_unset=True)
    if "email" in changes and changes["email"] is not None:
        changes["email"] = str(changes["email"]).lower()
    for field in ("email", "username"):
        candidate = changes.get(field)
        if candidate is not None:
            other = db.scalar(select(User).where(getattr(User, field) == candidate, User.id != user.id))
            if other is not None:
                raise HTTPException(status_code=409, detail=f"{field.capitalize()} is already in use")
    for key, value in changes.items():
        if value is not None:
            setattr(user, key, value)
    db.commit(); db.refresh(user)
    return user


@app.patch("/api/v1/users/me/password", status_code=204)
def change_password(data: PasswordChange, user: User = Depends(current_user), db: Session = Depends(get_db)):
    if not verify_password(data.current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    user.password_hash = hash_password(data.new_password)
    db.commit()
    return Response(status_code=204)


@app.get("/api/v1/boarding-houses", response_model=list[HouseOut])
def list_houses(q: str | None = None, location: str | None = None, min_price: Decimal | None = Query(default=None, ge=0),
                max_price: Decimal | None = Query(default=None, ge=0), room_type: str | None = None,
                amenity: str | None = None, page: int = Query(default=1, ge=1), page_size: int = Query(default=20, ge=1, le=100),
                db: Session = Depends(get_db)):
    stmt = select(BoardingHouse).where(
        BoardingHouse.status.in_(PUBLIC_LISTING_STATUSES),
    )
    if q:
        for term in listing_search_terms(q):
            stmt = stmt.where(or_(
                BoardingHouse.name.ilike(f"%{term}%"),
                BoardingHouse.location.ilike(f"%{term}%"),
                BoardingHouse.amenities.ilike(f"%{term}%"),
            ))
    if location:
        for term in listing_search_terms(location):
            stmt = stmt.where(BoardingHouse.location.ilike(f"%{term}%"))
    if min_price is not None:
        stmt = stmt.where(BoardingHouse.price >= min_price)
    if max_price is not None:
        stmt = stmt.where(BoardingHouse.price <= max_price)
    if room_type:
        stmt = stmt.where(BoardingHouse.room_type == room_type)
    rows = db.scalars(stmt.order_by(BoardingHouse.created_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()
    result = [house_out(row) for row in rows]
    if amenity:
        result = [row for row in result if amenity.casefold() in [x.casefold() for x in row.amenities]]
    return result


@app.get("/api/v1/boarding-houses/{house_id}", response_model=HouseOut)
def get_house(house_id: int, db: Session = Depends(get_db)):
    row = db.get(BoardingHouse, house_id)
    if row is None or row.status not in PUBLIC_LISTING_STATUSES:
        raise HTTPException(status_code=404, detail="Boarding house not found")
    return house_out(row)


@app.post("/api/v1/boarding-houses", response_model=HouseOut, status_code=201)
def create_house(data: HouseIn, user: User = Depends(owner_user), db: Session = Depends(get_db)):
    serialized = data.model_dump(exclude={"amenities", "safety_features", "utility_details", "status"})
    serialized["status"] = "Draft" if data.status == "Draft" else "Pending"
    serialized["amenities"] = ",".join(data.amenities)
    serialized["safety_features"] = ",".join(data.safety_features)
    serialized["utility_details"] = ",".join(data.utility_details)
    row = BoardingHouse(owner_id=user.id, **serialized)
    db.add(row); db.commit(); db.refresh(row)
    return house_out(row)


def owned_house(house_id: int, user: User, db: Session) -> BoardingHouse:
    row = db.get(BoardingHouse, house_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Boarding house not found")
    if row.owner_id != user.id:
        raise HTTPException(status_code=403, detail="You can only manage your own listings")
    return row


@app.patch("/api/v1/boarding-houses/{house_id}", response_model=HouseOut)
def patch_house(house_id: int, data: HousePatch, user: User = Depends(owner_user), db: Session = Depends(get_db)):
    row = owned_house(house_id, user, db)
    changes = data.model_dump(exclude_unset=True)
    if changes.get("status") == "Approved" and row.status != "Unavailable":
        raise HTTPException(status_code=403, detail="Only an administrator can approve a listing")
    material_changes = set(changes) - {"status", "available_rooms"}
    for key, value in changes.items():
        setattr(row, key, ",".join(value) if key in {"amenities", "safety_features", "utility_details"} and value is not None else value)
    # Approved listings stay live when owners maintain their details. A rejected
    # submission must return to review after its owner corrects the requested info.
    if row.status == "Rejected" and material_changes:
        row.status = "Pending"
        row.rejection_reason = None
    db.commit(); db.refresh(row)
    return house_out(row)


@app.delete("/api/v1/boarding-houses/{house_id}", status_code=204)
def delete_house(house_id: int, user: User = Depends(owner_user), db: Session = Depends(get_db)):
    row = owned_house(house_id, user, db)
    paths = [image.relative_path for image in row.images]
    db.delete(row)
    db.commit()
    root = settings.upload_dir.resolve()
    for relative_path in paths:
        candidate = (root / relative_path).resolve()
        if root in candidate.parents:
            try:
                candidate.unlink(missing_ok=True)
            except OSError:
                logger.warning("Could not remove a listing image after listing deletion")
    return Response(status_code=204)


@app.get("/api/v1/owners/me/boarding-houses", response_model=list[HouseOut])
def owner_houses(user: User = Depends(owner_user), db: Session = Depends(get_db)):
    return [house_out(row) for row in db.scalars(select(BoardingHouse).where(BoardingHouse.owner_id == user.id)).all()]


@app.get("/api/v1/map/boarding-houses", response_model=list[HouseOut])
def map_houses(db: Session = Depends(get_db)):
    rows = db.scalars(select(BoardingHouse).where(
        BoardingHouse.status.in_(PUBLIC_LISTING_STATUSES),
        BoardingHouse.latitude.is_not(None),
        BoardingHouse.longitude.is_not(None),
    )).all()
    return [house_out(row) for row in rows]


@app.get("/api/v1/favorites", response_model=list[HouseOut])
def list_favorites(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(BoardingHouse).join(Favorite).where(
        Favorite.user_id == user.id,
        BoardingHouse.status.in_(PUBLIC_LISTING_STATUSES),
    )).all()
    return [house_out(row) for row in rows]


@app.post("/api/v1/favorites/{house_id}", status_code=204)
def add_favorite(house_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    house = db.get(BoardingHouse, house_id)
    if house is None or house.status not in PUBLIC_LISTING_STATUSES:
        raise HTTPException(status_code=404, detail="Boarding house not found")
    exists = db.scalar(select(Favorite).where(Favorite.user_id == user.id, Favorite.boarding_house_id == house_id))
    if exists is None:
        db.add(Favorite(user_id=user.id, boarding_house_id=house_id)); db.commit()
    return Response(status_code=204)


@app.delete("/api/v1/favorites/{house_id}", status_code=204)
def remove_favorite(house_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    row = db.scalar(select(Favorite).where(Favorite.user_id == user.id, Favorite.boarding_house_id == house_id))
    if row is not None:
        db.delete(row); db.commit()
    return Response(status_code=204)


@app.post("/api/v1/boarding-houses/{house_id}/inquiries", response_model=InquiryOut, status_code=201)
def create_inquiry(
    house_id: int,
    data: InquiryIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    if user.role != "renter":
        raise HTTPException(status_code=403, detail="Renter account required")
    house = db.get(BoardingHouse, house_id)
    if house is None or house.status not in PUBLIC_LISTING_STATUSES or house.available_rooms <= 0:
        raise HTTPException(status_code=404, detail="Boarding house not found")
    inquiry = Inquiry(boarding_house_id=house.id, renter_id=user.id, message=data.message.strip())
    db.add(inquiry)
    db.commit()
    db.refresh(inquiry)
    return inquiry_out(inquiry)


@app.get("/api/v1/owners/me/inquiries", response_model=list[InquiryOut])
def owner_inquiries(user: User = Depends(owner_user), db: Session = Depends(get_db)):
    rows = db.scalars(
        select(Inquiry)
        .join(BoardingHouse)
        .where(BoardingHouse.owner_id == user.id)
        .order_by(Inquiry.created_at.desc())
    ).all()
    return [inquiry_out(row) for row in rows]


@app.get("/api/v1/users/me/inquiries", response_model=list[InquiryOut])
def renter_inquiries(user: User = Depends(current_user), db: Session = Depends(get_db)):
    rows = db.scalars(
        select(Inquiry)
        .where(Inquiry.renter_id == user.id)
        .order_by(Inquiry.created_at.desc())
    ).all()
    return [inquiry_out(row) for row in rows]


@app.patch("/api/v1/inquiries/{inquiry_id}/response", response_model=InquiryOut)
def respond_to_inquiry(
    inquiry_id: int,
    data: InquiryResponseIn,
    user: User = Depends(owner_user),
    db: Session = Depends(get_db),
):
    inquiry = db.get(Inquiry, inquiry_id)
    if inquiry is None:
        raise HTTPException(status_code=404, detail="Inquiry not found")
    if inquiry.boarding_house.owner_id != user.id:
        raise HTTPException(status_code=403, detail="You can only respond to inquiries on your listings")
    inquiry.response = data.response.strip()
    inquiry.status = "answered"
    db.commit()
    db.refresh(inquiry)
    return inquiry_out(inquiry)


@app.patch("/api/v1/inquiries/{inquiry_id}/close", response_model=InquiryOut)
def close_inquiry(
    inquiry_id: int,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    inquiry = db.get(Inquiry, inquiry_id)
    if inquiry is None:
        raise HTTPException(status_code=404, detail="Inquiry not found")
    if inquiry.renter_id != user.id:
        raise HTTPException(status_code=403, detail="You can only close your own inquiries")
    inquiry.status = "closed"
    db.commit()
    db.refresh(inquiry)
    return inquiry_out(inquiry)


@app.get("/api/v1/admin/summary", response_model=AdminSummary)
def admin_summary(user: User = Depends(admin_user), db: Session = Depends(get_db)):
    return AdminSummary(
        users=db.scalar(select(func.count(User.id))) or 0,
        renters=db.scalar(select(func.count(User.id)).where(func.lower(func.trim(User.role)) == "renter")) or 0,
        owners=db.scalar(select(func.count(User.id)).where(
            func.lower(func.trim(User.role)).in_(("owner", "property owner", "property_owner"))
        )) or 0,
        owners_with_listings=db.scalar(
            select(func.count(func.distinct(BoardingHouse.owner_id)))
        ) or 0,
        listings=db.scalar(select(func.count(BoardingHouse.id))) or 0,
        active_listings=db.scalar(
            select(func.count(BoardingHouse.id)).where(BoardingHouse.status.in_(PUBLIC_LISTING_STATUSES))
        ) or 0,
        inquiries=db.scalar(select(func.count(Inquiry.id))) or 0,
        pending_listings=db.scalar(
            select(func.count(BoardingHouse.id)).where(BoardingHouse.status == "Pending")
        ) or 0,
        pending_reports=db.scalar(
            select(func.count(IssueReport.id)).where(IssueReport.status == "Pending")
        ) or 0,
    )


@app.get("/api/v1/admin/users", response_model=list[AdminUserOut])
def admin_users(
    user: User = Depends(admin_user),
    db: Session = Depends(get_db),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=100),
):
    return db.scalars(
        select(User).order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    ).all()


@app.get("/api/v1/admin/listings", response_model=list[HouseOut])
def admin_listings(user: User = Depends(admin_user), db: Session = Depends(get_db)):
    rows = db.scalars(select(BoardingHouse).order_by(BoardingHouse.created_at.desc())).all()
    return [house_out(row) for row in rows]


@app.patch("/api/v1/admin/listings/{house_id}/status", response_model=HouseOut)
def admin_update_listing_status(
    house_id: int,
    data: ListingStatusIn,
    user: User = Depends(admin_user),
    db: Session = Depends(get_db),
):
    house = db.get(BoardingHouse, house_id)
    if house is None:
        raise HTTPException(status_code=404, detail="Boarding house not found")
    previous_status = house.status
    house.status = data.status
    house.rejection_reason = data.reason.strip() if data.status == "Rejected" and data.reason else None
    db.add(ListingModerationEvent(
        boarding_house_id=house.id,
        moderator_id=user.id,
        previous_status=previous_status,
        status=data.status,
        reason=house.rejection_reason,
    ))
    db.commit()
    db.refresh(house)
    return house_out(house)


@app.get("/api/v1/admin/listings/{house_id}/moderation-history")
def listing_moderation_history(
    house_id: int,
    user: User = Depends(admin_user),
    db: Session = Depends(get_db),
):
    if db.get(BoardingHouse, house_id) is None:
        raise HTTPException(status_code=404, detail="Boarding house not found")
    rows = db.scalars(
        select(ListingModerationEvent)
        .where(ListingModerationEvent.boarding_house_id == house_id)
        .order_by(ListingModerationEvent.created_at.desc())
    ).all()
    return [
        {
            "id": row.id,
            "moderator_id": row.moderator_id,
            "previous_status": row.previous_status,
            "status": row.status,
            "reason": row.reason,
            "created_at": row.created_at,
        }
        for row in rows
    ]


@app.get("/api/v1/admin/activity", response_model=AdminActivityPageOut)
def admin_activity(
    user: User = Depends(admin_user),
    db: Session = Depends(get_db),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
):
    listing_events = select(
        literal("listing").label("source"),
        ListingModerationEvent.id.label("source_id"),
        ListingModerationEvent.moderator_id.label("actor_id"),
        User.full_name.label("actor_name"),
        User.role.label("actor_role"),
        literal("Listing status changed").label("action"),
        literal("listing").label("target_type"),
        BoardingHouse.id.label("target_id"),
        BoardingHouse.name.label("target_label"),
        ListingModerationEvent.previous_status.label("previous_value"),
        ListingModerationEvent.status.label("new_value"),
        ListingModerationEvent.reason.label("description"),
        ListingModerationEvent.created_at.label("created_at"),
    ).join(User, ListingModerationEvent.moderator_id == User.id).join(
        BoardingHouse, ListingModerationEvent.boarding_house_id == BoardingHouse.id
    )
    report_status_events = select(
        literal("report_status").label("source"),
        IssueReportHistory.id.label("source_id"),
        IssueReportHistory.changed_by.label("actor_id"),
        User.full_name.label("actor_name"),
        User.role.label("actor_role"),
        literal("Report status changed").label("action"),
        literal("report").label("target_type"),
        IssueReport.id.label("target_id"),
        IssueReport.reference_number.label("target_label"),
        IssueReportHistory.previous_status.label("previous_value"),
        IssueReportHistory.new_status.label("new_value"),
        IssueReportHistory.remarks.label("description"),
        IssueReportHistory.created_at.label("created_at"),
    ).join(User, IssueReportHistory.changed_by == User.id).join(
        IssueReport, IssueReportHistory.report_id == IssueReport.id
    ).where(User.role == "admin")
    report_responses = select(
        literal("report_response").label("source"),
        IssueReportMessage.id.label("source_id"),
        IssueReportMessage.sender_id.label("actor_id"),
        User.full_name.label("actor_name"),
        User.role.label("actor_role"),
        literal("Report response sent").label("action"),
        literal("report").label("target_type"),
        IssueReport.id.label("target_id"),
        IssueReport.reference_number.label("target_label"),
        literal(None, type_=String()).label("previous_value"),
        literal(None, type_=String()).label("new_value"),
        IssueReportMessage.message.label("description"),
        IssueReportMessage.created_at.label("created_at"),
    ).join(User, IssueReportMessage.sender_id == User.id).join(
        IssueReport, IssueReportMessage.report_id == IssueReport.id
    ).where(User.role == "admin")
    events = union_all(listing_events, report_status_events, report_responses).subquery()
    total = db.scalar(select(func.count()).select_from(events)) or 0
    rows = db.execute(
        select(events)
        .order_by(events.c.created_at.desc(), events.c.source, events.c.source_id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).mappings().all()
    return {
        "items": [
            {
                "event_key": f"{row['source']}:{row['source_id']}",
                **{key: row[key] for key in (
                    "actor_id", "actor_name", "actor_role", "action", "target_type",
                    "target_id", "target_label", "previous_value", "new_value",
                    "description", "created_at",
                )},
            }
            for row in rows
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


MAX_IMAGE_BYTES = 5 * 1024 * 1024
MAX_IMAGES_PER_LISTING = 8
IMAGE_SIGNATURES = (
    (b"\x89PNG\r\n\x1a\n", "image/png", ".png"),
    (b"\xff\xd8\xff", "image/jpeg", ".jpg"),
    (b"RIFF", "image/webp", ".webp"),
)


def identify_image(payload: bytes) -> tuple[str, str] | None:
    for signature, content_type, extension in IMAGE_SIGNATURES:
        if payload.startswith(signature) and (
            content_type != "image/webp" or payload[8:12] == b"WEBP"
        ):
            return content_type, extension
    return None


REPORT_CATEGORIES = (
    "Account and Login Problems",
    "Boarding House Listing Issues",
    "Incorrect Property Information",
    "Map and Location Problems",
    "Inquiries and Messaging",
    "Technical Errors",
    "Security and Privacy Concerns",
    "Other",
)
REPORT_STATUSES = ("Pending", "Under Review", "Resolved", "Rejected")
REPORT_MAX_BYTES = 5 * 1024 * 1024
REPORT_MAX_PER_MINUTE = 5


def report_attachment_url(row: IssueReport) -> str | None:
    return f"/api/v1/reports/{row.id}/attachment" if row.attachment_path else None


def issue_report_out(row: IssueReport) -> dict:
    return {
        "id": row.id,
        "reference_number": row.reference_number,
        "user_id": row.user_id,
        "category": row.category,
        "subject": row.subject,
        "description": row.description,
        "attachment_url": report_attachment_url(row),
        "attachment_filename": row.attachment_filename,
        "status": row.status,
        "created_at": row.created_at,
        "updated_at": row.updated_at,
        "resolved_at": row.resolved_at,
    }


def issue_report_detail(row: IssueReport, db: Session, *, include_reporter: bool) -> dict:
    payload = issue_report_out(row)
    if include_reporter:
        payload.update({
            "reporter_name": row.reporter.full_name,
            "reporter_username": row.reporter.username,
            "reporter_email": row.reporter.email,
            "reporter_role": row.reporter.role,
        })
    payload["messages"] = [
        {
            "id": message.id,
            "sender_id": message.sender_id,
            "sender_name": message.sender.full_name,
            "sender_role": message.sender.role,
            "message": message.message,
            "created_at": message.created_at,
        }
        for message in row.messages
    ]
    payload["history"] = []
    for event in row.history:
        actor = db.get(User, event.changed_by)
        payload["history"].append({
            "id": event.id,
            "changed_by": event.changed_by,
            "changed_by_name": actor.full_name if actor else "BoardMap administrator",
            "previous_status": event.previous_status,
            "new_status": event.new_status,
            "remarks": event.remarks,
            "created_at": event.created_at,
        })
    return payload


def report_notification(db: Session, recipient_id: int, report: IssueReport, title: str, message: str) -> None:
    db.add(Notification(
        recipient_id=recipient_id,
        report_id=report.id,
        title=title[:120],
        message=message[:500],
    ))


def get_owned_report(report_id: int, user: User, db: Session) -> IssueReport:
    report = db.get(IssueReport, report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    if user.role != "admin" and report.user_id != user.id:
        raise HTTPException(status_code=403, detail="You are not authorized to access this report")
    return report


def private_report_file(relative_path: str) -> Path:
    root = settings.report_upload_dir.resolve()
    candidate = (root / relative_path).resolve()
    if root not in candidate.parents:
        raise HTTPException(status_code=404, detail="Attachment not found")
    return candidate


@app.post("/api/v1/reports", response_model=IssueReportOut, status_code=201)
async def create_issue_report(
    request: Request,
    category: str = Form(..., max_length=60),
    subject: str = Form(..., max_length=100),
    description: str = Form(..., max_length=2000),
    file: UploadFile | None = File(default=None),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    if user.role not in ("renter", "owner"):
        raise HTTPException(status_code=403, detail="Only renters and property owners can submit reports")
    enforce_rate_limit(request, "issue-report", REPORT_MAX_PER_MINUTE)
    category = category.strip()
    subject = subject.strip()
    description = description.strip()
    if category not in REPORT_CATEGORIES:
        raise HTTPException(status_code=422, detail="Please select a valid issue category")
    if not subject or len(subject) > 100:
        raise HTTPException(status_code=422, detail="Please enter a subject of up to 100 characters")
    if not description or len(description) > 2000:
        raise HTTPException(status_code=422, detail="Please describe the issue in up to 2,000 characters")

    duplicate_since = datetime.now(timezone.utc) - timedelta(seconds=30)
    duplicate = db.scalar(select(IssueReport.id).where(
        IssueReport.user_id == user.id,
        IssueReport.category == category,
        IssueReport.subject == subject,
        IssueReport.description == description,
        IssueReport.status.in_(("Pending", "Under Review")),
        IssueReport.created_at >= duplicate_since,
    ))
    if duplicate is not None:
        raise HTTPException(status_code=409, detail="A matching report was just submitted. Please wait before submitting it again.")

    stored_path = None
    original_name = None
    destination: Path | None = None
    if file is not None:
        payload = await file.read(REPORT_MAX_BYTES + 1)
        await file.close()
        if not payload or len(payload) > REPORT_MAX_BYTES:
            raise HTTPException(status_code=413, detail="File size exceeds the 5 MB limit")
        detected = identify_image(payload)
        if detected is None:
            raise HTTPException(status_code=415, detail="Unsupported file format. Please upload JPG, PNG, or WEBP.")
        _, extension = detected
        safe_original = Path(file.filename or "attachment").name
        safe_original = re.sub(r"[^A-Za-z0-9_. -]", "_", safe_original)[:160] or "attachment"
        original_name = safe_original
        stored_path = f"{uuid4().hex}{extension}"
        destination = private_report_file(stored_path)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(payload)

    now = datetime.now(timezone.utc)
    reference = f"CBR-{now:%Y%m%d}-{uuid4().hex[:8].upper()}"
    report = IssueReport(
        reference_number=reference,
        user_id=user.id,
        category=category,
        subject=subject,
        description=description,
        attachment_path=stored_path,
        attachment_filename=original_name,
        status="Pending",
        created_at=now,
        updated_at=now,
    )
    db.add(report)
    try:
        db.flush()
        db.add(IssueReportHistory(
            report_id=report.id,
            changed_by=user.id,
            previous_status=None,
            new_status="Pending",
            remarks="Report submitted",
            created_at=now,
        ))
        report_notification(db, user.id, report, "Report submitted", f"Your report {reference} has been received.")
        admin_ids = db.scalars(select(User.id).where(User.role == "admin")).all()
        for admin_id in admin_ids:
            report_notification(db, admin_id, report, "New issue report", f"{reference}: {subject}")
        db.commit()
        db.refresh(report)
    except Exception:
        db.rollback()
        if destination is not None:
            destination.unlink(missing_ok=True)
        raise
    return issue_report_out(report)


@app.get("/api/v1/reports/my", response_model=IssueReportPageOut)
def my_issue_reports(
    status: str | None = Query(default=None),
    q: str | None = Query(default=None, max_length=100),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    statement = select(IssueReport).where(IssueReport.user_id == user.id)
    if status and status != "All":
        if status not in REPORT_STATUSES:
            raise HTTPException(status_code=422, detail="Invalid report status")
        statement = statement.where(IssueReport.status == status)
    if q and q.strip():
        statement = statement.where(IssueReport.subject.ilike(f"%{q.strip()}%"))
    total = db.scalar(select(func.count()).select_from(statement.order_by(None).subquery())) or 0
    rows = db.scalars(statement.order_by(IssueReport.created_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()
    return {"items": [issue_report_out(row) for row in rows], "total": total, "page": page, "page_size": page_size}


@app.get("/api/v1/reports/{report_id}", response_model=IssueReportDetailOut)
def my_issue_report_detail(report_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    report = get_owned_report(report_id, user, db)
    return issue_report_detail(report, db, include_reporter=False)


@app.get("/api/v1/reports/{report_id}/attachment")
def get_issue_report_attachment(report_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    report = get_owned_report(report_id, user, db)
    if not report.attachment_path:
        raise HTTPException(status_code=404, detail="This report has no attachment")
    file_path = private_report_file(report.attachment_path)
    if not file_path.is_file():
        raise HTTPException(status_code=404, detail="Attachment not found")
    extension = file_path.suffix.lower()
    media_type = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"}.get(extension, "application/octet-stream")
    safe_name = f"report-{report.reference_number}{extension}"
    return FileResponse(file_path, media_type=media_type, filename=safe_name, headers={"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"})


@app.get("/api/v1/reports/{report_id}/messages", response_model=list[IssueReportMessageOut])
def issue_report_messages(report_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    report = get_owned_report(report_id, user, db)
    return issue_report_detail(report, db, include_reporter=False)["messages"]


@app.post("/api/v1/reports/{report_id}/messages", response_model=IssueReportMessageOut, status_code=201)
def reply_to_issue_report(report_id: int, data: IssueReportMessageIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    report = get_owned_report(report_id, user, db)
    if user.role == "admin":
        raise HTTPException(status_code=405, detail="Administrators should use the report response endpoint")
    message_text = data.message.strip()
    message = IssueReportMessage(report_id=report.id, sender_id=user.id, message=message_text)
    db.add(message)
    for admin_id in db.scalars(select(User.id).where(User.role == "admin")).all():
        report_notification(db, admin_id, report, "Report follow-up", f"{report.reference_number}: {message_text[:350]}")
    report.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(message)
    return {
        "id": message.id,
        "sender_id": user.id,
        "sender_name": user.full_name,
        "sender_role": user.role,
        "message": message.message,
        "created_at": message.created_at,
    }


@app.get("/api/v1/admin/reports/statistics", response_model=IssueReportStatistics)
def admin_issue_report_statistics(user: User = Depends(admin_user), db: Session = Depends(get_db)):
    counts = {status: count for status, count in db.execute(
        select(IssueReport.status, func.count(IssueReport.id)).group_by(IssueReport.status)
    ).all()}
    return {
        "total": sum(counts.values()),
        "pending": counts.get("Pending", 0),
        "under_review": counts.get("Under Review", 0),
        "resolved": counts.get("Resolved", 0),
        "rejected": counts.get("Rejected", 0),
    }


@app.get("/api/v1/admin/reports", response_model=IssueReportPageOut)
def admin_issue_reports(
    status: str | None = Query(default=None),
    category: str | None = Query(default=None),
    q: str | None = Query(default=None, max_length=100),
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    user: User = Depends(admin_user),
    db: Session = Depends(get_db),
):
    statement = select(IssueReport)
    if status and status != "All":
        if status not in REPORT_STATUSES:
            raise HTTPException(status_code=422, detail="Invalid report status")
        statement = statement.where(IssueReport.status == status)
    if category and category != "All":
        if category not in REPORT_CATEGORIES:
            raise HTTPException(status_code=422, detail="Invalid report category")
        statement = statement.where(IssueReport.category == category)
    if q and q.strip():
        search = f"%{q.strip()}%"
        statement = statement.join(User, IssueReport.user_id == User.id).where(or_(IssueReport.subject.ilike(search), IssueReport.reference_number.ilike(search), User.username.ilike(search), User.full_name.ilike(search)))
    if start_date:
        statement = statement.where(IssueReport.created_at >= datetime.combine(start_date, datetime_time.min, tzinfo=timezone.utc))
    if end_date:
        statement = statement.where(IssueReport.created_at < datetime.combine(end_date + timedelta(days=1), datetime_time.min, tzinfo=timezone.utc))
    total = db.scalar(select(func.count()).select_from(statement.order_by(None).subquery())) or 0
    rows = db.scalars(statement.order_by(IssueReport.created_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()
    items = []
    for row in rows:
        item = issue_report_out(row)
        item.update({
            "reporter_name": row.reporter.full_name,
            "reporter_username": row.reporter.username,
            "reporter_role": row.reporter.role,
        })
        items.append(item)
    return {"items": items, "total": total, "page": page, "page_size": page_size}


@app.get("/api/v1/admin/reports/{report_id}", response_model=IssueReportDetailOut)
def admin_issue_report_detail(report_id: int, user: User = Depends(admin_user), db: Session = Depends(get_db)):
    report = get_owned_report(report_id, user, db)
    return issue_report_detail(report, db, include_reporter=True)


@app.patch("/api/v1/admin/reports/{report_id}/status", response_model=IssueReportDetailOut)
def admin_update_issue_report_status(report_id: int, data: IssueReportStatusIn, user: User = Depends(admin_user), db: Session = Depends(get_db)):
    report = get_owned_report(report_id, user, db)
    allowed = {
        "Pending": {"Under Review", "Rejected"},
        "Under Review": {"Resolved", "Rejected"},
        "Resolved": set(),
        "Rejected": set(),
    }
    if data.status == report.status:
        raise HTTPException(status_code=409, detail="The report already has this status")
    if data.status not in allowed.get(report.status, set()):
        raise HTTPException(status_code=409, detail=f"Cannot change a {report.status} report to {data.status}")
    previous = report.status
    now = datetime.now(timezone.utc)
    report.status = data.status
    report.updated_at = now
    report.resolved_at = now if data.status == "Resolved" else None
    db.add(IssueReportHistory(
        report_id=report.id,
        changed_by=user.id,
        previous_status=previous,
        new_status=data.status,
        remarks=data.remarks.strip() if data.remarks else None,
        created_at=now,
    ))
    report_notification(db, report.user_id, report, "Report status updated", f"Your report {report.reference_number} is now {data.status}.")
    db.commit()
    db.refresh(report)
    return issue_report_detail(report, db, include_reporter=True)


@app.post("/api/v1/admin/reports/{report_id}/respond", response_model=IssueReportMessageOut, status_code=201)
def admin_respond_to_issue_report(report_id: int, data: IssueReportMessageIn, user: User = Depends(admin_user), db: Session = Depends(get_db)):
    report = get_owned_report(report_id, user, db)
    message = IssueReportMessage(report_id=report.id, sender_id=user.id, message=data.message.strip())
    db.add(message)
    report.updated_at = datetime.now(timezone.utc)
    report_notification(db, report.user_id, report, "New response to your report", f"An administrator replied to {report.reference_number}.")
    db.commit()
    db.refresh(message)
    return {
        "id": message.id,
        "sender_id": user.id,
        "sender_name": user.full_name,
        "sender_role": user.role,
        "message": message.message,
        "created_at": message.created_at,
    }


@app.get("/api/v1/admin/reports/{report_id}/history")
def admin_issue_report_history(report_id: int, user: User = Depends(admin_user), db: Session = Depends(get_db)):
    report = get_owned_report(report_id, user, db)
    return issue_report_detail(report, db, include_reporter=False)["history"]


@app.get("/api/v1/notifications/my", response_model=list[NotificationOut])
def my_notifications(page: int = Query(default=1, ge=1), page_size: int = Query(default=50, ge=1, le=100), user: User = Depends(current_user), db: Session = Depends(get_db)):
    return db.scalars(select(Notification).where(Notification.recipient_id == user.id).order_by(Notification.created_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()


@app.patch("/api/v1/notifications/{notification_id}/read", response_model=NotificationOut)
def mark_notification_read(notification_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    notification = db.get(Notification, notification_id)
    if notification is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    if notification.recipient_id != user.id:
        raise HTTPException(status_code=403, detail="You are not authorized to access this notification")
    if notification.read_at is None:
        notification.read_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(notification)
    return notification


@app.post("/api/v1/boarding-houses/{house_id}/images", response_model=HouseOut, status_code=201)
async def upload_house_image(
    house_id: int,
    file: UploadFile = File(...),
    user: User = Depends(owner_user),
    db: Session = Depends(get_db),
):
    house = owned_house(house_id, user, db)
    if len(house.images) >= MAX_IMAGES_PER_LISTING:
        raise HTTPException(status_code=400, detail="A listing can have at most 8 images")
    payload = await file.read(MAX_IMAGE_BYTES + 1)
    await file.close()
    if not payload or len(payload) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image must be between 1 byte and 5 MB")
    detected = identify_image(payload)
    if detected is None:
        raise HTTPException(status_code=415, detail="Upload a PNG, JPEG, or WebP image")
    content_type, extension = detected
    filename = f"{uuid4().hex}{extension}"
    relative_path = f"{house_id}/{filename}"
    destination = settings.upload_dir / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(payload)
    image = HouseImage(
        boarding_house_id=house_id,
        uploaded_by=user.id,
        relative_path=relative_path,
        content_type=content_type,
    )
    db.add(image)
    try:
        db.commit()
        db.refresh(house)
    except Exception:
        db.rollback()
        destination.unlink(missing_ok=True)
        raise
    return house_out(house)


@app.post("/api/v1/users/me/photo", response_model=UserOut)
async def upload_profile_photo(
    file: UploadFile = File(...),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    payload = await file.read(MAX_IMAGE_BYTES + 1)
    await file.close()
    if not payload or len(payload) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image must be between 1 byte and 5 MB")
    detected = identify_image(payload)
    if detected is None:
        raise HTTPException(status_code=415, detail="Upload a PNG, JPEG, or WebP image")
    _, extension = detected
    relative_path = f"profiles/{user.id}/{uuid4().hex}{extension}"
    destination = settings.upload_dir / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(payload)
    previous_path = user.profile_photo_path
    user.profile_photo_path = relative_path
    try:
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        destination.unlink(missing_ok=True)
        raise
    if previous_path:
        root = settings.upload_dir.resolve()
        old_file = (root / previous_path).resolve()
        if root in old_file.parents:
            try:
                old_file.unlink(missing_ok=True)
            except OSError:
                logger.warning("Could not remove a replaced profile photo file")
    return user


@app.delete("/api/v1/users/me/photo", status_code=204)
def delete_profile_photo(user: User = Depends(current_user), db: Session = Depends(get_db)):
    relative_path = user.profile_photo_path
    user.profile_photo_path = None
    db.commit()
    root = settings.upload_dir.resolve()
    if relative_path:
        old_file = (root / relative_path).resolve()
        if root in old_file.parents:
            try:
                old_file.unlink(missing_ok=True)
            except OSError:
                logger.warning("Could not remove a profile photo file")
    return Response(status_code=204)


@app.delete("/api/v1/boarding-houses/{house_id}/images/{image_id}", status_code=204)
def delete_house_image(
    house_id: int,
    image_id: int,
    user: User = Depends(owner_user),
    db: Session = Depends(get_db),
):
    owned_house(house_id, user, db)
    image = db.get(HouseImage, image_id)
    if image is None or image.boarding_house_id != house_id:
        raise HTTPException(status_code=404, detail="Listing image not found")
    relative_path = image.relative_path
    db.delete(image)
    db.commit()
    root = settings.upload_dir.resolve()
    candidate = (root / relative_path).resolve()
    if root in candidate.parents:
        try:
            candidate.unlink(missing_ok=True)
        except OSError:
            logger.warning("Could not remove a listing image file")
    return Response(status_code=204)


@app.get("/api/v1/recommendations", response_model=list[RecommendationOut])
def recommendations(min_price: Decimal | None = Query(default=None, ge=0), max_price: Decimal | None = Query(default=None, ge=0),
                    room_type: str | None = None, location: str | None = None, amenities: str | None = None,
                    user: User = Depends(current_user), db: Session = Depends(get_db)):
    if min_price is not None and max_price is not None and min_price > max_price:
        raise HTTPException(status_code=422, detail="min_price must be less than or equal to max_price")
    stmt = select(BoardingHouse).where(
        BoardingHouse.status.in_(PUBLIC_LISTING_STATUSES),
    )
    if min_price is not None: stmt = stmt.where(BoardingHouse.price >= min_price)
    if max_price is not None: stmt = stmt.where(BoardingHouse.price <= max_price)
    if location and location.casefold() != "cabadbaran city":
        for term in listing_search_terms(location):
            stmt = stmt.where(BoardingHouse.location.ilike(f"%{term}%"))
    amenity_filters = [value.strip() for value in (amenities or "").split(",") if value.strip()]
    rows = db.scalars(stmt.order_by(BoardingHouse.created_at.desc()).limit(500)).all()
    ranked = rank_with_knn(
        rows,
        min_price=float(min_price) if min_price is not None else None,
        max_price=float(max_price) if max_price is not None else None,
        room_type=room_type,
        location=location,
        amenities={value.casefold() for value in amenity_filters},
    )
    if ranked is None:
        rows.sort(key=lambda house: (house.available_rooms <= 0, float(house.price), -house.created_at.timestamp()))
        limitation = "KNN needs at least two eligible listings; ranked by availability and price."
    else:
        rows = sorted(ranked, key=lambda house: house.available_rooms <= 0)
        limitation = "Ranked by KNN similarity across active listing data."
    output = []
    for row in rows:
        reasons = []
        if min_price is not None or max_price is not None: reasons.append("Within your selected budget")
        if room_type:
            if row.room_type.strip().casefold() == room_type.strip().casefold():
                reasons.append(f"Room type matches: {row.room_type}")
            else:
                reasons.append(f"Preferred room type: {room_type}; listing offers {row.room_type}")
        if location: reasons.append(f"Located in {row.location}")
        if amenity_filters:
            requested_keys = {
                re.sub(r"[^a-z0-9]+", " ", value.casefold()).strip()
                for value in amenity_filters
            }
            matched_amenities = [
                item.strip()
                for item in row.amenities.split(",")
                if re.sub(r"[^a-z0-9]+", " ", item.casefold()).strip() in requested_keys
            ]
            if len(matched_amenities) == len(amenity_filters):
                reasons.append(f"Includes {', '.join(amenity_filters)}")
            elif matched_amenities:
                reasons.append(f"Matches {len(matched_amenities)} of {len(amenity_filters)} selected amenities")
                reasons.append(f"Includes {', '.join(matched_amenities)}")
            else:
                reasons.append("Does not list the selected amenities")
        if row.available_rooms > 0:
            reasons.append("Rooms are currently listed as available")
        else:
            reasons.append("Currently full - no rooms listed as available")
        reasons.append(limitation)
        output.append(RecommendationOut(**house_out(row).model_dump(), match_reasons=reasons))
    return output
