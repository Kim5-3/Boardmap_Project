"""Apply BoardMap's approved public-schema setup using a hidden owner-password prompt.

Run from the Backend directory. This leaves the legacy system_core schema untouched.
"""

from getpass import getpass
import os
from pathlib import Path
import sys

from dotenv import dotenv_values
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url


BACKEND_DIR = Path(__file__).resolve().parent
os.chdir(BACKEND_DIR)

# Read only the connection target from the local app configuration. Never print it.
env_values = dotenv_values(BACKEND_DIR / ".env", interpolate=False)
configured_url = env_values.get("DATABASE_URL")
if not configured_url:
    raise SystemExit("DATABASE_URL is missing from Backend/.env")

app_url = make_url(configured_url)
if app_url.host not in {"localhost", "127.0.0.1", "::1"} or app_url.database != "boardmap_db":
    raise SystemExit("Refusing to modify a non-local or unexpected database")
if not app_url.username:
    raise SystemExit("The application role is missing from DATABASE_URL")

owner_name = input("Database owner role [postgres]: ").strip() or "postgres"
owner_password = getpass("Database owner password (input hidden): ")
if not owner_password:
    raise SystemExit("An owner password is required")

owner_url = app_url.set(username=owner_name, password=owner_password)
os.environ["DATABASE_URL"] = owner_url.render_as_string(hide_password=False)

owner_engine = None
try:
    # Import Alembic only after DATABASE_URL is set so migrations use the owner login.
    from alembic import command
    from alembic.config import Config

    # Confirm the target and application role before creating any objects.
    owner_engine = create_engine(owner_url, pool_pre_ping=True)
    with owner_engine.connect() as connection:
        connection.execute(text("SET TRANSACTION READ ONLY"))
        actual_db, actual_owner, role_can_login = connection.execute(
            text(
                "SELECT current_database(), current_user, "
                "COALESCE((SELECT rolcanlogin FROM pg_roles WHERE rolname=:role), false)"
            ),
            {"role": app_url.username},
        ).one()
        if actual_db != "boardmap_db":
            raise RuntimeError("Connected to an unexpected database")
        if not role_can_login:
            raise RuntimeError("The application role does not exist or cannot log in")
        if actual_owner != owner_name:
            raise RuntimeError("PostgreSQL authenticated a different owner role")

    # The approved initial migration creates only the app's public tables. It does
    # not alter system_core; its compatibility guard aborts on incompatible public tables.
    command.upgrade(Config(str(BACKEND_DIR / "alembic.ini")), "head")

    role_sql = owner_engine.dialect.identifier_preparer.quote(app_url.username)
    with owner_engine.begin() as connection:
        connection.exec_driver_sql(f"GRANT USAGE ON SCHEMA public TO {role_sql}")
        connection.exec_driver_sql(f"GRANT SELECT, INSERT ON TABLE public.users TO {role_sql}")
        sequence = connection.execute(
            text("SELECT pg_get_serial_sequence('public.users', 'id')")
        ).scalar_one_or_none()
        if not sequence:
            raise RuntimeError("Could not identify the users ID sequence")
        connection.exec_driver_sql(
            f"GRANT USAGE, SELECT ON SEQUENCE {sequence} TO {role_sql}"
        )
        checks = connection.execute(
            text(
                "SELECT has_schema_privilege(:role, 'public', 'USAGE'), "
                "has_table_privilege(:role, 'public.users', 'SELECT'), "
                "has_table_privilege(:role, 'public.users', 'INSERT'), "
                "has_sequence_privilege(:role, :sequence, 'USAGE'), "
                "has_sequence_privilege(:role, :sequence, 'SELECT')"
            ),
            {"role": app_url.username, "sequence": sequence},
        ).one()

    if not all(checks):
        raise RuntimeError("Post-migration privilege verification failed")
    print("Migration applied and registration privileges verified.")
    print("Legacy system_core tables were not modified.")
except Exception as exc:
    print(f"Repair stopped ({type(exc).__name__}); database details were suppressed.")
    sys.exit(1)
finally:
    if owner_engine is not None:
        owner_engine.dispose()
    os.environ.pop("DATABASE_URL", None)
