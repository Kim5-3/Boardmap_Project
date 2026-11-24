"""Create an administrator account interactively; public registration cannot do this.

Run from the Backend directory after migrations: python create_admin.py
"""
from getpass import getpass
import re

from sqlalchemy import or_, select

from app.database import SessionLocal
from app.models import User
from app.security import hash_password


def main() -> None:
    full_name = input("Administrator full name: ").strip()
    username = input("Administrator username: ").strip()
    email = input("Administrator email: ").strip().lower()
    if len(full_name) < 2 or not re.fullmatch(r"[A-Za-z0-9_.-]{3,40}", username):
        raise SystemExit("Name or username is invalid.")
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        raise SystemExit("Email address is invalid.")
    password = getpass("Administrator password (minimum 12 characters): ")
    confirmation = getpass("Confirm password: ")
    if len(password) < 12 or password != confirmation:
        raise SystemExit("Passwords must match and contain at least 12 characters.")

    with SessionLocal() as db:
        duplicate = db.scalar(
            select(User).where(or_(User.email == email, User.username == username))
        )
        if duplicate is not None:
            raise SystemExit("That email or username already exists; no account was changed.")
        account = User(
            full_name=full_name,
            username=username,
            email=email,
            password_hash=hash_password(password),
            role="admin",
        )
        db.add(account)
        db.commit()
        print(f"Administrator account created (user id {account.id}).")


if __name__ == "__main__":
    main()
