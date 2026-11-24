"""Create BoardMap tables after checking legacy table compatibility.

Revision ID: 0001_initial
Revises:
"""
from alembic import op
from sqlalchemy import inspect
from app.database import Base
from app import models  # noqa: F401

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = inspect(op.get_bind())
    required = {
        "users": {"id", "full_name", "username", "email", "password_hash", "role"},
        "boarding_houses": {"id", "owner_id", "name", "location", "price", "available_rooms", "latitude", "longitude", "amenities", "rules", "curfew_details", "safety_features", "utility_details", "gender_policy", "deposit_terms", "campus_distance_km"},
        "favorites": {"id", "user_id", "boarding_house_id"},
    }
    tables = set(inspector.get_table_names())
    for table, expected in required.items():
        if table in tables:
            found = {column["name"] for column in inspector.get_columns(table)}
            if not expected.issubset(found):
                missing = ", ".join(sorted(expected - found))
                raise RuntimeError(
                    f"Existing table '{table}' is not compatible with this migration "
                    f"(missing: {missing}). No tables were changed. Inspect the current "
                    "schema and write a reviewed data-preserving migration before retrying."
                )
    Base.metadata.create_all(bind=op.get_bind(), checkfirst=True)


def downgrade() -> None:
    raise RuntimeError("Initial BoardMap migration is intentionally non-destructive; remove tables manually only after backup and review.")
