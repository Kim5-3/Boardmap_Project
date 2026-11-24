"""Add user issue reports, conversations, status history, and notifications.

Revision ID: 0006_issue_reports
Revises: 0005_profile_photos
"""
from alembic import op
import sqlalchemy as sa


revision = "0006_issue_reports"
down_revision = "0005_profile_photos"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "issue_reports",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("reference_number", sa.String(length=24), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("category", sa.String(length=60), nullable=False),
        sa.Column("subject", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("attachment_path", sa.String(length=300), nullable=True),
        sa.Column("attachment_filename", sa.String(length=160), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="Pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("status IN ('Pending', 'Under Review', 'Resolved', 'Rejected')", name="ck_issue_reports_status"),
        sa.UniqueConstraint("reference_number", name="uq_issue_reports_reference_number"),
    )
    op.create_index("ix_issue_reports_reference_number", "issue_reports", ["reference_number"])
    op.create_index("ix_issue_reports_user_id", "issue_reports", ["user_id"])
    op.create_index("ix_issue_reports_category", "issue_reports", ["category"])
    op.create_index("ix_issue_reports_status", "issue_reports", ["status"])
    op.create_index("ix_issue_reports_created_at", "issue_reports", ["created_at"])
    op.create_index("ix_issue_reports_user_created", "issue_reports", ["user_id", "created_at"])
    op.create_index("ix_issue_reports_status_created", "issue_reports", ["status", "created_at"])

    op.create_table(
        "issue_report_messages",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("report_id", sa.Integer(), sa.ForeignKey("issue_reports.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sender_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_issue_report_messages_report_id", "issue_report_messages", ["report_id"])
    op.create_index("ix_issue_report_messages_sender_id", "issue_report_messages", ["sender_id"])
    op.create_index("ix_issue_report_messages_created_at", "issue_report_messages", ["created_at"])
    op.create_index("ix_issue_report_messages_report_created", "issue_report_messages", ["report_id", "created_at"])

    op.create_table(
        "issue_report_history",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("report_id", sa.Integer(), sa.ForeignKey("issue_reports.id", ondelete="CASCADE"), nullable=False),
        sa.Column("changed_by", sa.Integer(), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("previous_status", sa.String(length=20), nullable=True),
        sa.Column("new_status", sa.String(length=20), nullable=False),
        sa.Column("remarks", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_issue_report_history_report_id", "issue_report_history", ["report_id"])
    op.create_index("ix_issue_report_history_changed_by", "issue_report_history", ["changed_by"])
    op.create_index("ix_issue_report_history_created_at", "issue_report_history", ["created_at"])
    op.create_index("ix_issue_report_history_report_created", "issue_report_history", ["report_id", "created_at"])

    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("recipient_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("message", sa.String(length=500), nullable=False),
        sa.Column("report_id", sa.Integer(), sa.ForeignKey("issue_reports.id", ondelete="CASCADE"), nullable=True),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_notifications_recipient_id", "notifications", ["recipient_id"])
    op.create_index("ix_notifications_report_id", "notifications", ["report_id"])
    op.create_index("ix_notifications_created_at", "notifications", ["created_at"])
    op.create_index("ix_notifications_recipient_created", "notifications", ["recipient_id", "created_at"])


def downgrade() -> None:
    raise RuntimeError("Issue reports and notification history are retained; use a reviewed, backed-up rollback.")
