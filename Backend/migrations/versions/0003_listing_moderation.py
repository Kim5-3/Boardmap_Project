"""Add listing rejection feedback and a moderation history.

Revision ID: 0003_listing_moderation
Revises: 0002_inquiries_images
"""
from alembic import op
import sqlalchemy as sa


revision = "0003_listing_moderation"
down_revision = "0002_inquiries_images"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("boarding_houses", sa.Column("rejection_reason", sa.Text(), nullable=True))
    op.create_table(
        "listing_moderation_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "boarding_house_id",
            sa.Integer(),
            sa.ForeignKey("boarding_houses.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "moderator_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("previous_status", sa.String(length=20), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_listing_moderation_events_boarding_house_id",
        "listing_moderation_events",
        ["boarding_house_id"],
    )
    op.create_index(
        "ix_listing_moderation_events_moderator_id",
        "listing_moderation_events",
        ["moderator_id"],
    )


def downgrade() -> None:
    raise RuntimeError(
        "Moderation history is retained for auditability; use a reviewed, backed-up rollback."
    )
