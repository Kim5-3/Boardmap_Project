import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Keep tests independent of developer PostgreSQL credentials and never touch a real DB.
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-with-more-than-32-characters"

from app.database import Base, get_db
from app.main import app
from app.config import settings


@pytest.fixture
def client(monkeypatch):
    from app import main
    main._login_attempts.clear()
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    TestingSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    app.state.testing_session_factory = TestingSession
    Base.metadata.create_all(engine)

    def override_db():
        db = TestingSession()
        try:
            yield db
        finally:
            db.close()

    monkeypatch.setattr(settings, "jwt_secret_key", "test-secret-key-with-more-than-32-characters")
    app.dependency_overrides[get_db] = override_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    del app.state.testing_session_factory
    Base.metadata.drop_all(engine)
    engine.dispose()


def register(client, *, role="renter", username="sample_user", email="sample@example.com"):
    return client.post("/api/v1/auth/register", json={
        "full_name": "Sample User", "username": username, "email": email,
        "password": "correct-horse-battery", "role": role,
    })
