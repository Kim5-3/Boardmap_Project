"""Store user contact numbers supplied at registration or profile edit.

Revision ID: 0004_contact_numbers
Revises: 0003_listing_moderation
"""
from alembic import op
import sqlalchemy as sa


revision = "0004_contact_numbers"
down_revision = "0003_listing_moderation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("contact_number", sa.String(length=32), nullable=True))


def downgrade() -> None:
    raise RuntimeError(
        "Contact information is retained; back up and review user data before any rollback."
    )
