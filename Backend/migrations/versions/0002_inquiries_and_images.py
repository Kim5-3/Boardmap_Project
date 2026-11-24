"""Add persistent property inquiries and uploaded images.

Revision ID: 0002_inquiries_images
Revises: 0001_initial
"""
from alembic import op
import sqlalchemy as sa


revision = "0002_inquiries_images"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "inquiries",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "boarding_house_id",
            sa.Integer(),
            sa.ForeignKey("boarding_houses.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "renter_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("response", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_inquiries_boarding_house_id", "inquiries", ["boarding_house_id"])
    op.create_index("ix_inquiries_renter_id", "inquiries", ["renter_id"])
    op.create_index("ix_inquiries_status", "inquiries", ["status"])

    op.create_table(
        "house_images",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "boarding_house_id",
            sa.Integer(),
            sa.ForeignKey("boarding_houses.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "uploaded_by",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("relative_path", sa.String(length=300), nullable=False, unique=True),
        sa.Column("content_type", sa.String(length=40), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_house_images_boarding_house_id", "house_images", ["boarding_house_id"])
    op.create_index("ix_house_images_uploaded_by", "house_images", ["uploaded_by"])


def downgrade() -> None:
    raise RuntimeError(
        "This migration is intentionally non-destructive; review and back up new data "
        "before writing a purpose-built rollback."
    )
