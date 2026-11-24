def register(client, *, role="renter", username="sample_user", email="sample@example.com", password="correct-horse-battery"):
    return client.post("/api/v1/auth/register", json={
        "full_name": "Sample User", "username": username, "email": email,
        "password": password, "role": role,
    })


def create_test_admin(client):
    from app.main import app
    from app.models import User
    from app.security import hash_password

    db = app.state.testing_session_factory()
    db.add(User(
        full_name="BoardMap Admin",
        username="test_admin",
        email="admin@example.com",
        password_hash=hash_password("admin-test-password"),
        role="admin",
    ))
    db.commit()
    db.close()
    response = client.post("/api/v1/auth/login", json={
        "identifier": "test_admin", "password": "admin-test-password",
    })
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def approve_listing(client, listing_id, admin_headers):
    response = client.patch(
        f"/api/v1/admin/listings/{listing_id}/status",
        headers=admin_headers,
        json={"status": "Approved"},
    )
    assert response.status_code == 200
    return response.json()


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_cors_allows_flutter_localhost_dynamic_port_but_not_public_hosts(client):
    local = client.get("/health", headers={"Origin": "http://localhost:62302"})
    assert local.headers["access-control-allow-origin"] == "http://localhost:62302"
    public = client.get("/health", headers={"Origin": "https://example.invalid"})
    assert "access-control-allow-origin" not in public.headers


def test_readiness_checks_database_connection(client):
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok"}


def test_registration_rejects_short_password(client):
    response = register(client, password="short")
    assert response.status_code == 422


def test_database_connection_failure_returns_503(client, monkeypatch):
    from sqlalchemy.exc import OperationalError
    from app.database import get_db
    from app.main import app

    def unavailable_database():
        raise OperationalError("connect", {}, RuntimeError("sensitive driver detail"))

    monkeypatch.setitem(app.dependency_overrides, get_db, unavailable_database)
    response = register(client, username="database_failure", email="database-failure@example.com")
    assert response.status_code == 503
    assert response.json() == {
        "detail": "Database unavailable. Check PostgreSQL connectivity and application-role credentials."
    }
    assert "sensitive driver detail" not in response.text


def test_missing_database_table_returns_actionable_503(client, monkeypatch):
    from sqlalchemy.exc import ProgrammingError
    from app.database import get_db
    from app.main import app

    original = RuntimeError("SQL details must not be exposed")
    original.sqlstate = "42P01"

    def missing_schema():
        raise ProgrammingError("sensitive statement", {}, original)

    monkeypatch.setitem(app.dependency_overrides, get_db, missing_schema)
    response = register(client, username="missing_schema", email="missing-schema@example.com")
    assert response.status_code == 503
    assert response.json() == {
        "detail": "Database schema is not initialized. Apply the reviewed Alembic migrations."
    }
    assert "SQL details must not be exposed" not in response.text


def test_missing_database_permission_returns_actionable_503(client, monkeypatch):
    from sqlalchemy.exc import ProgrammingError
    from app.database import get_db
    from app.main import app

    original = RuntimeError("sensitive permission details")
    original.sqlstate = "42501"

    def insufficient_permissions():
        raise ProgrammingError("sensitive statement", {}, original)

    monkeypatch.setitem(app.dependency_overrides, get_db, insufficient_permissions)
    response = register(client, username="missing_permission", email="missing-permission@example.com")
    assert response.status_code == 503
    assert response.json() == {
        "detail": "The application database role lacks required table permissions."
    }
    assert "sensitive permission details" not in response.text


def test_registration_login_and_duplicate_account(client):
    created = register(client)
    assert created.status_code == 201
    assert "password_hash" not in created.json()["user"]
    assert register(client).status_code == 409
    login = client.post("/api/v1/auth/login", json={"identifier": "sample_user", "password": "correct-horse-battery"})
    assert login.status_code == 200
    assert login.json()["access_token"]
    assert client.post("/api/v1/auth/login", json={"identifier": "sample_user", "password": "wrong"}).status_code == 401


def test_registration_generates_username_when_not_supplied(client):
    response = client.post("/api/v1/auth/register", json={
        "full_name": "Simple Signup", "email": "simple.signup@example.com",
        "contact_number": "+639123456789", "password": "correct-horse-battery", "role": "renter",
    })
    assert response.status_code == 201
    assert response.json()["user"]["username"]
    assert response.json()["user"]["contact_number"] == "+639123456789"
    second = client.post("/api/v1/auth/register", json={
        "full_name": "Another Signup", "email": "simple.signup@other.example",
        "password": "correct-horse-battery", "role": "owner",
    })
    assert second.status_code == 201
    assert second.json()["user"]["username"] != response.json()["user"]["username"]
    assert client.post("/api/v1/auth/login", json={
        "identifier": "simple.signup@example.com", "password": "correct-horse-battery",
    }).status_code == 200


def test_owner_listing_ownership_and_favorites(client):
    owner = register(client, role="owner", username="owner1", email="owner@example.com").json()
    renter = register(client, username="renter1", email="renter@example.com").json()
    owner_headers = {"Authorization": f"Bearer {owner['access_token']}"}
    renter_headers = {"Authorization": f"Bearer {renter['access_token']}"}
    payload = {
        "name": "CSU House", "location": "Cabadbaran City", "price": "2500.00",
        "available_rooms": 2, "room_type": "Solo", "amenities": ["Wi-Fi"],
        "curfew_details": "10 PM", "safety_features": ["CCTV"],
        "utility_details": ["Water included"], "gender_policy": "Female only",
        "deposit_terms": "One month deposit", "campus_distance_km": 1.2,
        "latitude": 9.1222, "longitude": 125.535,
    }
    created = client.post("/api/v1/boarding-houses", json=payload, headers=owner_headers)
    assert created.status_code == 201
    house_id = created.json()["id"]
    assert created.json()["status"] == "Pending"
    assert client.get("/api/v1/boarding-houses").json() == []
    assert client.get("/api/v1/map/boarding-houses").json() == []
    assert client.patch(f"/api/v1/boarding-houses/{house_id}", json={"status": "Approved"}, headers=owner_headers).status_code == 403
    approve_listing(client, house_id, create_test_admin(client))
    assert client.get("/api/v1/boarding-houses").json()[0]["name"] == "CSU House"
    assert client.get("/api/v1/map/boarding-houses").json()[0]["latitude"] == 9.1222
    assert created.json()["safety_features"] == ["CCTV"]
    assert created.json()["curfew_details"] == "10 PM"
    assert client.patch(f"/api/v1/boarding-houses/{house_id}", json={"name": "Changed"}, headers=renter_headers).status_code == 403
    assert client.post(f"/api/v1/favorites/{house_id}", headers=renter_headers).status_code == 204
    assert client.post(f"/api/v1/favorites/{house_id}", headers=renter_headers).status_code == 204
    assert len(client.get("/api/v1/favorites", headers=renter_headers).json()) == 1
    assert client.delete(f"/api/v1/favorites/{house_id}", headers=renter_headers).status_code == 204


def test_inquiry_flow_is_persistent_and_owner_scoped(client):
    owner = register(client, role="owner", username="inqowner", email="inqowner@example.com").json()
    renter = register(client, username="inqrenter", email="inqrenter@example.com").json()
    other = register(client, role="owner", username="otherowner", email="otherowner@example.com").json()
    owner_headers = {"Authorization": f"Bearer {owner['access_token']}"}
    renter_headers = {"Authorization": f"Bearer {renter['access_token']}"}
    other_headers = {"Authorization": f"Bearer {other['access_token']}"}
    listing = client.post("/api/v1/boarding-houses", headers=owner_headers, json={
        "name": "Inquiry House", "location": "Town", "price": 2400,
        "available_rooms": 1, "room_type": "Solo", "amenities": [],
    }).json()
    approve_listing(client, listing['id'], create_test_admin(client))
    sent = client.post(f"/api/v1/boarding-houses/{listing['id']}/inquiries",
                       headers=renter_headers, json={"message": "Is this room available?"})
    assert sent.status_code == 201
    inquiry_id = sent.json()["id"]
    assert client.get("/api/v1/owners/me/inquiries", headers=owner_headers).json()[0]["message"] == "Is this room available?"
    assert client.get("/api/v1/owners/me/inquiries", headers=other_headers).json() == []
    assert client.patch(f"/api/v1/inquiries/{inquiry_id}/response", headers=other_headers,
                        json={"response": "Yes"}).status_code == 403
    answered = client.patch(f"/api/v1/inquiries/{inquiry_id}/response", headers=owner_headers,
                            json={"response": "Yes, it is available."})
    assert answered.status_code == 200
    assert answered.json()["status"] == "answered"
    assert client.get("/api/v1/users/me/inquiries", headers=renter_headers).json()[0]["response"] == "Yes, it is available."


def test_admin_endpoints_reject_non_admin_users(client):
    renter = register(client, username="notadmin", email="notadmin@example.com").json()
    headers = {"Authorization": f"Bearer {renter['access_token']}"}
    assert client.get("/api/v1/admin/summary").status_code == 401
    assert client.get("/api/v1/admin/summary", headers=headers).status_code == 403


def test_listing_moderation_requires_reason_and_owner_edits_resubmit(client):
    owner = register(client, role="owner", username="reviewowner", email="reviewowner@example.com").json()
    owner_headers = {"Authorization": f"Bearer {owner['access_token']}"}
    admin_headers = create_test_admin(client)
    listing = client.post("/api/v1/boarding-houses", headers=owner_headers, json={
        "name": "Review House", "location": "Town", "price": 2400,
        "available_rooms": 1, "room_type": "Solo", "amenities": [],
    }).json()
    listing_id = listing['id']
    assert client.patch(f"/api/v1/admin/listings/{listing_id}/status", headers=admin_headers,
                        json={"status": "Rejected"}).status_code == 422
    rejected = client.patch(f"/api/v1/admin/listings/{listing_id}/status", headers=admin_headers,
                            json={"status": "Rejected", "reason": "Add the complete address."})
    assert rejected.status_code == 200
    assert rejected.json()['rejection_reason'] == "Add the complete address."
    assert client.get(f"/api/v1/admin/listings/{listing_id}/moderation-history",
                      headers=admin_headers).json()[0]['reason'] == "Add the complete address."
    revised = client.patch(f"/api/v1/boarding-houses/{listing_id}", headers=owner_headers,
                           json={"location": "Purok 2, Poblacion, Cabadbaran City"})
    assert revised.status_code == 200
    assert revised.json()['status'] == "Pending"
    assert revised.json()['rejection_reason'] is None


def test_owner_image_upload_is_scoped_and_stored(client, monkeypatch, tmp_path):
    from app.config import settings

    monkeypatch.setattr(settings, "upload_dir", tmp_path)
    owner = register(client, role="owner", username="imageowner", email="imageowner@example.com").json()
    renter = register(client, username="imagerenter", email="imagerenter@example.com").json()
    owner_headers = {"Authorization": f"Bearer {owner['access_token']}"}
    renter_headers = {"Authorization": f"Bearer {renter['access_token']}"}
    listing = client.post("/api/v1/boarding-houses", headers=owner_headers, json={
        "name": "Photo House", "location": "Town", "price": 2400,
        "available_rooms": 1, "room_type": "Solo", "amenities": [],
    }).json()
    image = ("house.png", b"\x89PNG\r\n\x1a\n" + b"test-image-data", "application/octet-stream")
    path = f"/api/v1/boarding-houses/{listing['id']}/images"
    assert client.post(path, headers=renter_headers, files={"file": image}).status_code == 403
    uploaded = client.post(path, headers=owner_headers, files={"file": image})
    assert uploaded.status_code == 201
    assert len(uploaded.json()["image_urls"]) == 1
    stored = next(tmp_path.rglob("*.png"))
    assert stored.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")


def test_profile_photo_upload_is_private_and_replaceable(client, monkeypatch, tmp_path):
    from app.config import settings

    monkeypatch.setattr(settings, "upload_dir", tmp_path)
    session = register(client, username="photo_user", email="photo-user@example.com").json()
    headers = {"Authorization": f"Bearer {session['access_token']}"}
    path = "/api/v1/users/me/photo"
    png = ("profile.png", b"\x89PNG\r\n\x1a\nprofile-image", "image/png")
    uploaded = client.post(path, headers=headers, files={"file": png})
    assert uploaded.status_code == 200
    photo_url = uploaded.json()["profile_photo_url"]
    assert photo_url.startswith("/uploads/profiles/")
    stored = next(tmp_path.rglob("*.png"))
    assert stored.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    removed = client.delete(path, headers=headers)
    assert removed.status_code == 204
    assert client.get("/api/v1/users/me", headers=headers).json()["profile_photo_url"] is None
    assert not stored.exists()


def test_listing_filters_and_pagination(client):
    owner = register(client, role="owner", username="owner2", email="owner2@example.com").json()
    headers = {"Authorization": f"Bearer {owner['access_token']}"}
    for idx, price in enumerate((1000, 3000)):
        response = client.post("/api/v1/boarding-houses", headers=headers, json={
            "name": f"House {idx}", "location": "Poblacion", "price": price,
            "available_rooms": 1, "room_type": "Shared", "amenities": ["Wi-Fi"],
        })
        assert response.status_code == 201
        if idx == 1:
            admin = create_test_admin(client)
            for listing in client.get('/api/v1/admin/listings', headers=admin).json():
                approve_listing(client, listing['id'], admin)
    result = client.get("/api/v1/boarding-houses?min_price=2000&amenity=Wi-Fi&page=1&page_size=1")
    assert [row["name"] for row in result.json()] == ["House 1"]


def test_zero_room_listing_is_public_and_mappable_but_not_inquiry_eligible(client):
    owner = register(client, role="owner", username="full_owner", email="full-owner@example.com").json()
    owner_headers = {"Authorization": f"Bearer {owner['access_token']}"}
    created = client.post("/api/v1/boarding-houses", headers=owner_headers, json={
        "name": "Full House", "location": "Poblacion", "price": 2500,
        "available_rooms": 0, "room_type": "Solo", "amenities": [],
        "latitude": 9.118222, "longitude": 125.538389,
    })
    assert created.status_code == 201
    admin_headers = create_test_admin(client)
    response = client.patch(
        f"/api/v1/admin/listings/{created.json()['id']}/status",
        headers=admin_headers,
        json={"status": "Approved"},
    )
    assert response.status_code == 200
    house_id = created.json()["id"]
    assert [item["id"] for item in client.get("/api/v1/boarding-houses").json()] == [house_id]
    assert client.get(f"/api/v1/boarding-houses/{house_id}").json()["available_rooms"] == 0
    assert [item["id"] for item in client.get("/api/v1/map/boarding-houses").json()] == [house_id]
    renter = register(client, username="full_renter", email="full-renter@example.com").json()
    renter_headers = {"Authorization": f"Bearer {renter['access_token']}"}
    inquiry = client.post(
        f"/api/v1/boarding-houses/{house_id}/inquiries",
        headers=renter_headers,
        json={"message": "Is there a room available?"},
    )
    assert inquiry.status_code == 404


def test_approved_listing_with_rooms_and_coordinates_appears_in_browse_and_map(client):
    owner = register(client, role="owner", username="mapped_owner", email="mapped-owner@example.com").json()
    headers = {"Authorization": f"Bearer {owner['access_token']}"}
    created = client.post("/api/v1/boarding-houses", headers=headers, json={
        "name": "Map Ready House", "location": "Cabadbaran City", "price": 2500,
        "available_rooms": 2, "room_type": "Solo", "amenities": [],
        "latitude": 9.118222, "longitude": 125.538389,
    })
    assert created.status_code == 201
    admin_headers = create_test_admin(client)
    approved = approve_listing(client, created.json()["id"], admin_headers)
    assert approved["status"] == "Approved"
    assert [item["id"] for item in client.get("/api/v1/boarding-houses").json()] == [approved["id"]]
    assert [item["id"] for item in client.get("/api/v1/map/boarding-houses").json()] == [approved["id"]]

def test_profile_and_password_change(client):
    session = register(client).json()
    headers = {"Authorization": f"Bearer {session['access_token']}"}
    assert client.patch("/api/v1/users/me", headers=headers, json={"full_name": "Updated Name"}).json()["full_name"] == "Updated Name"
    changed = client.patch("/api/v1/users/me/password", headers=headers, json={
        "current_password": "correct-horse-battery", "new_password": "new-correct-password",
    })
    assert changed.status_code == 204
    assert client.post("/api/v1/auth/login", json={"identifier": "sample_user", "password": "new-correct-password"}).status_code == 200


def test_recommendations_explain_filtered_matches(client):
    owner = register(client, role="owner", username="owner3", email="owner3@example.com").json()
    renter = register(client, username="renter3", email="renter3@example.com").json()
    headers = {"Authorization": f"Bearer {owner['access_token']}"}
    created = client.post("/api/v1/boarding-houses", headers=headers, json={
        "name": "Near CSU", "location": "Cabadbaran City", "price": 2200,
        "available_rooms": 1, "room_type": "Solo", "amenities": ["Wi-Fi"],
    })
    assert created.status_code == 201
    second = client.post("/api/v1/boarding-houses", headers=headers, json={
        "name": "Campus Home", "location": "Cabadbaran City", "price": 2500,
        "available_rooms": 2, "room_type": "Solo", "amenities": ["Wi-Fi"],
    })
    assert second.status_code == 201
    admin = create_test_admin(client)
    approve_listing(client, created.json()['id'], admin)
    approve_listing(client, second.json()['id'], admin)
    auth = {"Authorization": f"Bearer {renter['access_token']}"}
    response = client.get("/api/v1/recommendations?min_price=1000&max_price=3000&room_type=Solo&amenities=Wi-Fi", headers=auth)
    assert response.status_code == 200
    assert "Includes Wi-Fi" in response.json()[0]["match_reasons"]
    assert "KNN similarity" in response.json()[0]["match_reasons"][-1]
    assert client.get("/api/v1/recommendations").status_code == 401


def test_admin_attention_activity_log_and_read_only_account_roles(client):
    owner = register(client, role="owner", username="audit_owner", email="audit-owner@example.com").json()
    renter = register(client, username="audit_renter", email="audit-renter@example.com").json()
    admin_headers = create_test_admin(client)
    owner_headers = {"Authorization": f"Bearer {owner['access_token']}"}
    renter_headers = {"Authorization": f"Bearer {renter['access_token']}"}

    pending_listing = client.post("/api/v1/boarding-houses", headers=owner_headers, json={
        "name": "Awaiting Review", "location": "Town", "price": 2200,
        "available_rooms": 1, "room_type": "Solo", "amenities": [],
    })
    assert pending_listing.status_code == 201
    reviewed_listing = client.patch(
        f"/api/v1/admin/listings/{pending_listing.json()['id']}/status",
        headers=admin_headers,
        json={"status": "Approved"},
    )
    assert reviewed_listing.status_code == 200

    report = client.post("/api/v1/reports", headers=renter_headers, data={
        "category": "Technical Errors",
        "subject": "Cannot save changes",
        "description": "Saving the profile returns an error.",
    })
    assert report.status_code == 201
    report_id = report.json()["id"]
    assert client.patch(f"/api/v1/admin/reports/{report_id}/status", headers=admin_headers,
                        json={"status": "Under Review"}).status_code == 200
    assert client.post(f"/api/v1/admin/reports/{report_id}/respond", headers=admin_headers,
                       json={"message": "We are investigating this issue."}).status_code == 201

    pending_summary = client.get("/api/v1/admin/summary", headers=admin_headers)
    assert pending_summary.status_code == 200
    assert pending_summary.json()["pending_listings"] == 0
    assert pending_summary.json()["pending_reports"] == 0

    # Add one item to each queue to verify counts reflect live records.
    second_listing = client.post("/api/v1/boarding-houses", headers=owner_headers, json={
        "name": "Still Pending", "location": "Town", "price": 2400,
        "available_rooms": 1, "room_type": "Solo", "amenities": [],
    })
    second_report = client.post("/api/v1/reports", headers=renter_headers, data={
        "category": "Technical Errors",
        "subject": "Search is slow",
        "description": "The search page takes too long to load.",
    })
    assert second_listing.status_code == 201
    assert second_report.status_code == 201
    summary = client.get("/api/v1/admin/summary", headers=admin_headers).json()
    assert summary["pending_listings"] == 1
    assert summary["pending_reports"] == 1

    activity = client.get("/api/v1/admin/activity?page=1&page_size=2", headers=admin_headers)
    assert activity.status_code == 200, activity.text
    assert activity.json()["total"] == 3
    assert len(activity.json()["items"]) == 2
    all_activity = client.get("/api/v1/admin/activity?page=1&page_size=10", headers=admin_headers)
    assert {row["action"] for row in all_activity.json()["items"]} == {
        "Listing status changed", "Report status changed", "Report response sent"
    }
    assert all(row["actor_name"] == "BoardMap Admin" for row in all_activity.json()["items"])
    assert client.get("/api/v1/admin/activity", headers=renter_headers).status_code == 403

    # Account role is descriptive only; the old mutation endpoint is gone.
    role_change = client.patch("/api/v1/admin/users/%s/role" % renter["user"]["id"],
                               headers=admin_headers, json={"role": "owner"})
    assert role_change.status_code == 404
    accounts = client.get("/api/v1/admin/users", headers=admin_headers).json()
    assert next(row for row in accounts if row["id"] == renter["user"]["id"])["role"] == "renter"


def test_issue_report_conversation_status_permissions_and_notifications(client):
    renter = register(client, username="report_renter", email="report-renter@example.com").json()
    other = register(client, username="other_renter", email="other-renter@example.com").json()
    renter_headers = {"Authorization": f"Bearer {renter['access_token']}"}
    other_headers = {"Authorization": f"Bearer {other['access_token']}"}
    admin_headers = create_test_admin(client)

    form = {
        "category": "Map and Location Problems",
        "subject": "Map pin is misplaced",
        "description": "The listing pin appears on the wrong street.",
    }
    assert client.post("/api/v1/reports", data=form).status_code == 401
    submitted = client.post("/api/v1/reports", headers=renter_headers, data=form)
    assert submitted.status_code == 201, submitted.text
    report = submitted.json()
    assert report["status"] == "Pending"
    assert report["reference_number"].startswith("CBR-")

    own_reports = client.get("/api/v1/reports/my", headers=renter_headers)
    assert own_reports.status_code == 200
    assert own_reports.json()["total"] == 1
    assert client.get(f"/api/v1/reports/{report['id']}", headers=other_headers).status_code == 403
    assert client.get("/api/v1/admin/reports", headers=renter_headers).status_code == 403
    assert client.get("/api/v1/admin/reports/statistics", headers=other_headers).status_code == 403

    stats = client.get("/api/v1/admin/reports/statistics", headers=admin_headers).json()
    assert stats == {"total": 1, "pending": 1, "under_review": 0, "resolved": 0, "rejected": 0}
    assert client.patch(f"/api/v1/admin/reports/{report['id']}/status", headers=admin_headers,
                        json={"status": "Resolved"}).status_code == 409
    rejected_without_reason = client.patch(f"/api/v1/admin/reports/{report['id']}/status", headers=admin_headers,
                                           json={"status": "Rejected"})
    assert rejected_without_reason.status_code == 422

    reviewed = client.patch(f"/api/v1/admin/reports/{report['id']}/status", headers=admin_headers,
                            json={"status": "Under Review"})
    assert reviewed.status_code == 200
    reply = client.post(f"/api/v1/admin/reports/{report['id']}/respond", headers=admin_headers,
                        json={"message": "We are checking the location."})
    assert reply.status_code == 201
    user_detail = client.get(f"/api/v1/reports/{report['id']}", headers=renter_headers).json()
    assert user_detail["messages"][0]["message"] == "We are checking the location."
    assert user_detail["history"][-1]["new_status"] == "Under Review"

    rejected = client.patch(f"/api/v1/admin/reports/{report['id']}/status", headers=admin_headers,
                            json={"status": "Rejected", "remarks": "Duplicate report."})
    assert rejected.status_code == 200
    assert rejected.json()["status"] == "Rejected"
    assert len(rejected.json()["history"]) == 3
    assert client.patch(f"/api/v1/admin/reports/{report['id']}/status", headers=admin_headers,
                        json={"status": "Resolved"}).status_code == 409

    notifications = client.get("/api/v1/notifications/my", headers=renter_headers)
    assert notifications.status_code == 200
    assert len(notifications.json()) >= 3
    notification = notifications.json()[0]
    marked = client.patch(f"/api/v1/notifications/{notification['id']}/read", headers=other_headers)
    assert marked.status_code == 403
    assert client.patch(f"/api/v1/notifications/{notification['id']}/read", headers=renter_headers).status_code == 200


def test_issue_report_attachments_are_validated_and_private(client, monkeypatch, tmp_path):
    from app.config import settings

    monkeypatch.setattr(settings, "report_upload_dir", tmp_path)
    owner = register(client, role="owner", username="report_owner", email="report-owner@example.com").json()
    renter = register(client, username="report_viewer", email="report-viewer@example.com").json()
    owner_headers = {"Authorization": f"Bearer {owner['access_token']}"}
    renter_headers = {"Authorization": f"Bearer {renter['access_token']}"}
    form = {"category": "Technical Errors", "subject": "Page error", "description": "A page stops loading."}

    invalid = client.post("/api/v1/reports", headers=owner_headers, data=form,
                          files={"file": ("payload.png", b"not-an-image", "image/png")})
    assert invalid.status_code == 415
    too_large = client.post("/api/v1/reports", headers=owner_headers, data=form,
                            files={"file": ("large.png", b"\x89PNG\r\n\x1a\n" + b"x" * (5 * 1024 * 1024), "image/png")})
    assert too_large.status_code == 413

    image = ("screen shot.png", b"\x89PNG\r\n\x1a\nvalid-signature", "image/png")
    created = client.post("/api/v1/reports", headers=owner_headers, data=form, files={"file": image})
    assert created.status_code == 201, created.text
    report = created.json()
    assert report["attachment_url"] == f"/api/v1/reports/{report['id']}/attachment"
    assert client.get(report["attachment_url"], headers=owner_headers).content.startswith(b"\x89PNG\r\n\x1a\n")
    assert client.get(report["attachment_url"], headers=renter_headers).status_code == 403
    assert len(list(tmp_path.iterdir())) == 1


def test_issue_report_duplicate_submit_and_owner_flow(client):
    owner = register(client, role="owner", username="duplicate_owner", email="duplicate-owner@example.com").json()
    headers = {"Authorization": f"Bearer {owner['access_token']}"}
    form = {"category": "Other", "subject": "Need help", "description": "Please review this issue."}
    first = client.post("/api/v1/reports", headers=headers, data=form)
    assert first.status_code == 201
    duplicate = client.post("/api/v1/reports", headers=headers, data=form)
    assert duplicate.status_code == 409
