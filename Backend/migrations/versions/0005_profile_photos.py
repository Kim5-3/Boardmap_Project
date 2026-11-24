"""Add a stored profile photo reference to accounts.

Revision ID: 0005_profile_photos
Revises: 0004_contact_numbers
"""
from alembic import op
import sqlalchemy as sa


revision = "0005_profile_photos"
down_revision = "0004_contact_numbers"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("profile_photo_path", sa.String(length=300), nullable=True))


def downgrade() -> None:
    raise RuntimeError(
        "Profile photo references are retained; back up and review user data before rollback."
    )
