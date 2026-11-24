from datetime import datetime, timezone
from decimal import Decimal
from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    full_name: Mapped[str] = mapped_column(String(120))
    username: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True)
    contact_number: Mapped[str | None] = mapped_column(String(32), nullable=True)
    profile_photo_path: Mapped[str | None] = mapped_column(String(300), nullable=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(16), default="renter")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    listings: Mapped[list["BoardingHouse"]] = relationship(back_populates="owner")
    favorites: Mapped[list["Favorite"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    inquiries: Mapped[list["Inquiry"]] = relationship(back_populates="renter", cascade="all, delete-orphan")
    issue_reports: Mapped[list["IssueReport"]] = relationship(back_populates="reporter", foreign_keys="IssueReport.user_id")
    report_messages: Mapped[list["IssueReportMessage"]] = relationship(back_populates="sender", foreign_keys="IssueReportMessage.sender_id")
    notifications: Mapped[list["Notification"]] = relationship(back_populates="recipient", cascade="all, delete-orphan")

    @property
    def profile_photo_url(self) -> str | None:
        return f"/uploads/{self.profile_photo_path}" if self.profile_photo_path else None


class BoardingHouse(Base):
    __tablename__ = "boarding_houses"
    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(160), index=True)
    location: Mapped[str] = mapped_column(String(240), index=True)
    description: Mapped[str] = mapped_column(Text, default="")
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    available_rooms: Mapped[int] = mapped_column(Integer, default=0)
    room_type: Mapped[str] = mapped_column(String(40), default="Not specified")
    amenities: Mapped[str] = mapped_column(Text, default="")
    rules: Mapped[str] = mapped_column(Text, default="")
    curfew_details: Mapped[str] = mapped_column(Text, default="")
    safety_features: Mapped[str] = mapped_column(Text, default="")
    utility_details: Mapped[str] = mapped_column(Text, default="")
    gender_policy: Mapped[str] = mapped_column(String(100), default="")
    deposit_terms: Mapped[str] = mapped_column(Text, default="")
    campus_distance_km: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="Pending", index=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    latitude: Mapped[float | None] = mapped_column(Numeric(10, 7), nullable=True)
    longitude: Mapped[float | None] = mapped_column(Numeric(10, 7), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    owner: Mapped[User] = relationship(back_populates="listings")
    favorites: Mapped[list["Favorite"]] = relationship(back_populates="boarding_house", cascade="all, delete-orphan")
    inquiries: Mapped[list["Inquiry"]] = relationship(back_populates="boarding_house", cascade="all, delete-orphan")
    images: Mapped[list["HouseImage"]] = relationship(back_populates="boarding_house", cascade="all, delete-orphan")
    moderation_events: Mapped[list["ListingModerationEvent"]] = relationship(back_populates="boarding_house", cascade="all, delete-orphan")


class Favorite(Base):
    __tablename__ = "favorites"
    __table_args__ = (UniqueConstraint("user_id", "boarding_house_id", name="uq_favorite_user_house"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    boarding_house_id: Mapped[int] = mapped_column(ForeignKey("boarding_houses.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    user: Mapped[User] = relationship(back_populates="favorites")
    boarding_house: Mapped[BoardingHouse] = relationship(back_populates="favorites")


class Inquiry(Base):
    __tablename__ = "inquiries"
    id: Mapped[int] = mapped_column(primary_key=True)
    boarding_house_id: Mapped[int] = mapped_column(ForeignKey("boarding_houses.id", ondelete="CASCADE"), index=True)
    renter_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    message: Mapped[str] = mapped_column(Text)
    response: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(16), default="open", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)
    renter: Mapped[User] = relationship(back_populates="inquiries")
    boarding_house: Mapped[BoardingHouse] = relationship(back_populates="inquiries")


class HouseImage(Base):
    __tablename__ = "house_images"
    id: Mapped[int] = mapped_column(primary_key=True)
    boarding_house_id: Mapped[int] = mapped_column(ForeignKey("boarding_houses.id", ondelete="CASCADE"), index=True)
    uploaded_by: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    relative_path: Mapped[str] = mapped_column(String(300), unique=True)
    content_type: Mapped[str] = mapped_column(String(40))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    boarding_house: Mapped[BoardingHouse] = relationship(back_populates="images")


class ListingModerationEvent(Base):
    __tablename__ = "listing_moderation_events"
    id: Mapped[int] = mapped_column(primary_key=True)
    boarding_house_id: Mapped[int] = mapped_column(ForeignKey("boarding_houses.id", ondelete="CASCADE"), index=True)
    moderator_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"), index=True)
    previous_status: Mapped[str] = mapped_column(String(20))
    status: Mapped[str] = mapped_column(String(20))
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    boarding_house: Mapped[BoardingHouse] = relationship(back_populates="moderation_events")


class IssueReport(Base):
    __tablename__ = "issue_reports"
    __table_args__ = (
        CheckConstraint("status IN ('Pending', 'Under Review', 'Resolved', 'Rejected')", name="ck_issue_reports_status"),
        Index("ix_issue_reports_user_created", "user_id", "created_at"),
        Index("ix_issue_reports_status_created", "status", "created_at"),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    reference_number: Mapped[str] = mapped_column(String(24), unique=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"), index=True)
    category: Mapped[str] = mapped_column(String(60), index=True)
    subject: Mapped[str] = mapped_column(String(100))
    description: Mapped[str] = mapped_column(Text)
    attachment_path: Mapped[str | None] = mapped_column(String(300), nullable=True)
    attachment_filename: Mapped[str | None] = mapped_column(String(160), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="Pending", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reporter: Mapped[User] = relationship(back_populates="issue_reports", foreign_keys=[user_id])
    messages: Mapped[list["IssueReportMessage"]] = relationship(back_populates="report", cascade="all, delete-orphan", order_by="IssueReportMessage.created_at")
    history: Mapped[list["IssueReportHistory"]] = relationship(back_populates="report", cascade="all, delete-orphan", order_by="IssueReportHistory.created_at")
    notifications: Mapped[list["Notification"]] = relationship(back_populates="report", cascade="all, delete-orphan")


class IssueReportMessage(Base):
    __tablename__ = "issue_report_messages"
    __table_args__ = (Index("ix_issue_report_messages_report_created", "report_id", "created_at"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    report_id: Mapped[int] = mapped_column(ForeignKey("issue_reports.id", ondelete="CASCADE"), index=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"), index=True)
    message: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    report: Mapped[IssueReport] = relationship(back_populates="messages")
    sender: Mapped[User] = relationship(back_populates="report_messages", foreign_keys=[sender_id])


class IssueReportHistory(Base):
    __tablename__ = "issue_report_history"
    __table_args__ = (Index("ix_issue_report_history_report_created", "report_id", "created_at"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    report_id: Mapped[int] = mapped_column(ForeignKey("issue_reports.id", ondelete="CASCADE"), index=True)
    changed_by: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="RESTRICT"), index=True)
    previous_status: Mapped[str | None] = mapped_column(String(20), nullable=True)
    new_status: Mapped[str] = mapped_column(String(20))
    remarks: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    report: Mapped[IssueReport] = relationship(back_populates="history")


class Notification(Base):
    __tablename__ = "notifications"
    __table_args__ = (Index("ix_notifications_recipient_created", "recipient_id", "created_at"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    recipient_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(120))
    message: Mapped[str] = mapped_column(String(500))
    report_id: Mapped[int | None] = mapped_column(ForeignKey("issue_reports.id", ondelete="CASCADE"), nullable=True, index=True)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    recipient: Mapped[User] = relationship(back_populates="notifications")
    report: Mapped[IssueReport | None] = relationship(back_populates="notifications")
