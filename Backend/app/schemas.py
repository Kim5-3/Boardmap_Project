from datetime import datetime
from decimal import Decimal
from typing import Literal
from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator


class RegisterIn(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    contact_number: str | None = Field(default=None, min_length=7, max_length=32, pattern=r"^[+0-9() .-]{7,32}$")
    username: str | None = Field(default=None, min_length=3, max_length=40, pattern=r"^[A-Za-z0-9_.-]+$")
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    role: Literal["renter", "owner"] = "renter"


class LoginIn(BaseModel):
    identifier: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=1, max_length=128)


class UserOut(BaseModel):
    id: int
    full_name: str
    username: str
    email: EmailStr
    contact_number: str | None = None
    profile_photo_url: str | None = None
    role: str
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class UserPatch(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=120)
    username: str | None = Field(default=None, min_length=3, max_length=40, pattern=r"^[A-Za-z0-9_.-]+$")
    email: EmailStr | None = None
    contact_number: str | None = Field(default=None, min_length=7, max_length=32, pattern=r"^[+0-9() .-]{7,32}$")


class PasswordChange(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class HouseIn(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    location: str = Field(min_length=2, max_length=240)
    description: str = Field(default="", max_length=5000)
    price: Decimal = Field(gt=0, max_digits=10, decimal_places=2)
    available_rooms: int = Field(default=0, ge=0, le=1000)
    room_type: str = Field(default="Not specified", max_length=40)
    amenities: list[str] = Field(default_factory=list, max_length=40)
    rules: str = Field(default="", max_length=5000)
    curfew_details: str = Field(default="", max_length=500)
    safety_features: list[str] = Field(default_factory=list, max_length=40)
    utility_details: list[str] = Field(default_factory=list, max_length=40)
    gender_policy: str = Field(default="", max_length=100)
    deposit_terms: str = Field(default="", max_length=1000)
    campus_distance_km: Decimal | None = Field(default=None, ge=0, le=1000, max_digits=8, decimal_places=2)
    # Owners may save drafts or submit for moderation, but cannot publish listings.
    status: Literal["Draft", "Pending"] = "Pending"
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)

    @model_validator(mode="after")
    def coordinates_are_a_pair(self):
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("Latitude and longitude must be provided together")
        return self


class HousePatch(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=160)
    location: str | None = Field(default=None, min_length=2, max_length=240)
    description: str | None = Field(default=None, max_length=5000)
    price: Decimal | None = Field(default=None, gt=0, max_digits=10, decimal_places=2)
    available_rooms: int | None = Field(default=None, ge=0, le=1000)
    room_type: str | None = Field(default=None, max_length=40)
    amenities: list[str] | None = Field(default=None, max_length=40)
    rules: str | None = Field(default=None, max_length=5000)
    curfew_details: str | None = Field(default=None, max_length=500)
    safety_features: list[str] | None = Field(default=None, max_length=40)
    utility_details: list[str] | None = Field(default=None, max_length=40)
    gender_policy: str | None = Field(default=None, max_length=100)
    deposit_terms: str | None = Field(default=None, max_length=1000)
    campus_distance_km: Decimal | None = Field(default=None, ge=0, le=1000, max_digits=8, decimal_places=2)
    # Owner edits may pause a public listing, but only admins can approve it.
    status: Literal["Approved", "Unavailable"] | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)

    @model_validator(mode="after")
    def coordinates_are_a_pair_when_changed(self):
        fields = self.model_fields_set
        if ("latitude" in fields) != ("longitude" in fields):
            raise ValueError("Latitude and longitude must be updated together")
        return self


class HouseOut(BaseModel):
    id: int
    owner_id: int
    name: str
    location: str
    description: str
    price: Decimal
    available_rooms: int
    room_type: str
    amenities: list[str]
    rules: str
    curfew_details: str
    safety_features: list[str]
    utility_details: list[str]
    gender_policy: str
    deposit_terms: str
    campus_distance_km: Decimal | None
    status: str
    rejection_reason: str | None = None
    latitude: float | None
    longitude: float | None
    created_at: datetime
    image_urls: list[str] = Field(default_factory=list)


class RecommendationOut(HouseOut):
    match_reasons: list[str] = Field(default_factory=list)


class InquiryIn(BaseModel):
    message: str = Field(min_length=1, max_length=5000)


class InquiryResponseIn(BaseModel):
    response: str = Field(min_length=1, max_length=5000)


class InquiryOut(BaseModel):
    id: int
    boarding_house_id: int
    house_name: str
    renter_id: int
    renter_name: str
    renter_email: EmailStr
    message: str
    response: str | None
    status: Literal["open", "answered", "closed"]
    created_at: datetime


class AdminUserOut(UserOut):
    pass


class AdminSummary(BaseModel):
    users: int
    renters: int
    owners: int
    owners_with_listings: int
    listings: int
    active_listings: int
    inquiries: int
    pending_listings: int
    pending_reports: int


class AdminActivityOut(BaseModel):
    event_key: str
    actor_id: int
    actor_name: str
    actor_role: str
    action: str
    target_type: Literal["listing", "report"]
    target_id: int
    target_label: str
    previous_value: str | None = None
    new_value: str | None = None
    description: str | None = None
    created_at: datetime


class AdminActivityPageOut(BaseModel):
    items: list[AdminActivityOut]
    total: int
    page: int
    page_size: int


class ListingStatusIn(BaseModel):
    status: Literal["Approved", "Rejected", "Pending", "Draft", "Unavailable"]
    reason: str | None = Field(default=None, max_length=2000)

    @model_validator(mode="after")
    def rejected_requires_reason(self):
        if self.status == "Rejected" and not (self.reason or "").strip():
            raise ValueError("A rejection reason is required")
        return self


IssueReportStatus = Literal["Pending", "Under Review", "Resolved", "Rejected"]


class IssueReportStatusIn(BaseModel):
    status: IssueReportStatus
    remarks: str | None = Field(default=None, max_length=1000)

    @model_validator(mode="after")
    def rejected_requires_reason(self):
        if self.status == "Rejected" and not (self.remarks or "").strip():
            raise ValueError("A rejection reason is required")
        return self


class IssueReportMessageIn(BaseModel):
    message: str = Field(min_length=1, max_length=2000)

    @model_validator(mode="after")
    def message_must_not_be_blank(self):
        if not self.message.strip():
            raise ValueError("A message cannot be blank")
        return self


class IssueReportMessageOut(BaseModel):
    id: int
    sender_id: int
    sender_name: str
    sender_role: str
    message: str
    created_at: datetime


class IssueReportHistoryOut(BaseModel):
    id: int
    changed_by: int
    changed_by_name: str
    previous_status: str | None
    new_status: str
    remarks: str | None
    created_at: datetime


class IssueReportOut(BaseModel):
    id: int
    reference_number: str
    user_id: int
    category: str
    subject: str
    description: str
    attachment_url: str | None
    attachment_filename: str | None
    status: IssueReportStatus
    created_at: datetime
    updated_at: datetime
    resolved_at: datetime | None
    reporter_name: str | None = None
    reporter_username: str | None = None
    reporter_role: str | None = None


class IssueReportDetailOut(IssueReportOut):
    reporter_name: str | None = None
    reporter_username: str | None = None
    reporter_email: EmailStr | None = None
    reporter_role: str | None = None
    messages: list[IssueReportMessageOut] = Field(default_factory=list)
    history: list[IssueReportHistoryOut] = Field(default_factory=list)


class IssueReportPageOut(BaseModel):
    items: list[IssueReportOut]
    total: int
    page: int
    page_size: int


class IssueReportStatistics(BaseModel):
    total: int
    pending: int
    under_review: int
    resolved: int
    rejected: int


class NotificationOut(BaseModel):
    id: int
    recipient_id: int
    title: str
    message: str
    report_id: int | None
    read_at: datetime | None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)
