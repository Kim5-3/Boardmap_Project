# BoardMap API

FastAPI REST API for BoardMap, backed by PostgreSQL and SQLAlchemy 2. Apply Alembic
migrations before running the API. The local database is at revision `0006_issue_reports`
and intentionally contains no boarding-house records. Migrations add inquiry and listing
image tables, listing moderation history, account contact numbers, and profile-photo
references without resetting existing records. Revision `0006_issue_reports` adds the report
support workflow and database-backed in-app notifications; apply `alembic upgrade head`.
## Windows setup

```powershell
cd Backend
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

Create a PostgreSQL database and set `DATABASE_URL` to its application-role connection URL
and set a random `JWT_SECRET_KEY` in `.env`. Both values are required; the API fails during
startup if either is missing or the JWT secret is shorter than 32 characters. Do not use a
read-only role for registration. The application role needs database connect, schema usage,
and the table/sequence privileges required by its endpoints. Run Alembic migrations as a
database owner or migration role with the required DDL privileges, then run the API using
the application role. Use a 32-byte-or-longer secret in deployments.
This implementation uses numeric latitude/longitude and does not require PostGIS. Run
`alembic upgrade head`; the migration checks any same-named existing tables and aborts
without changes when required columns are missing. Review the schema and create a
data-preserving migration before retrying in that case. Do not run `create_all` or drop
tables to work around a mismatch.

The additive `0006_issue_reports` migration creates report, report-message, status-history,
and in-app notification tables. It preserves existing data. Apply it with
`alembic upgrade head` before using the support screens. Report attachments are validated as JPG, PNG, or
WebP (5 MB maximum) and stored under `REPORT_UPLOAD_DIR` (default: `private_reports` at the
repository root), outside the public `/uploads` directory. The API serves them only after
checking the authenticated user's ownership or administrator role. Back up this private
directory along with PostgreSQL data.

Start the service with `uvicorn app.main:app --reload --host 127.0.0.1 --port 8000`.
Swagger UI is at `http://127.0.0.1:8000/docs`; `/health` checks the process and `/ready`
checks the PostgreSQL connection.

Set `CORS_ORIGINS` to comma-separated exact frontend origins. Development also permits
loopback hosts on any port so Flutter web's dynamic port works. For production, set
`CORS_ORIGIN_REGEX=` (empty) and list only the deployed frontend origin in `CORS_ORIGINS`.
`AUTO_CREATE_TABLES` is intended only for isolated development/test databases and defaults
to false.

## API implemented

- Registration and login issue JWT sessions; passwords are stored as Argon2 hashes. Email is the recommended login identifier; the API generates a unique username if one is omitted.
- Public search, details, favorites, recommendations, and map endpoints return approved/legacy active listings, including full ones. The map additionally requires valid coordinates; new inquiries are disabled for full properties. Recommendations rank available places first and explain amenity and room-type matches.
- Owners can create and manage only their own listings. New listings are Draft or Pending; owners cannot approve themselves. Material edits to approved/rejected listings return them to Pending.
- Administrators have protected summary, user-read, listing-moderation, and moderation-history endpoints. Rejection requires a reason. Create the first administrator with `python create_admin.py` after migrations.
- Administrator account types are read-only in the dashboard and the former role-change API is removed. The admin summary includes live pending listing/report counts. `/api/v1/admin/activity` combines listing moderation events, report status changes, and administrator replies into a paginated, admin-only audit feed using the existing history tables.
- Renters and owners can submit reports, view only their own report threads and private attachments, and reply to administrators. Admins can search/filter reports, review reporter information, respond, and change status through Pending → Under Review → Resolved or Rejected. Rejections require a reason; status changes and messages are recorded and create in-app notifications.
- Notifications are available from `/api/v1/notifications/my` and can be marked read by their recipient. Report endpoints use `/api/v1/reports` and `/api/v1/admin/reports`.
- Renters and owners can submit reports and access only their own reports, messages, and private attachments. Administrators can search/filter reports, view reporter details, respond, and advance status through Pending → Under Review → Resolved/Rejected. Rejections require a reason; status changes and messages are recorded and notify recipients in-app.
- Notifications are available from `GET /api/v1/notifications/my` and can be marked read by their recipient. Support endpoints use the `/api/v1/reports` and `/api/v1/admin/reports` paths.
- Renter inquiries and owner replies are persisted in PostgreSQL.
- Owners can upload up to eight PNG, JPEG, or WebP property photos per listing (5 MB each). Users can upload or remove their own PNG, JPEG, or WebP profile photo (5 MB maximum). Files are stored under `Backend/uploads` and served from `/uploads`.
- Recommendations use Scikit-learn KNN over matching public listing data. If there are too few rows to compare, the API returns an explained availability/price fallback.

Email/push notifications and property-view analytics are not implemented. Browser access tokens restore from per-tab `sessionStorage`; the application has no refresh-token endpoint. The login/register rate limiter is process-local, so multi-worker deployments need a shared rate-limit store. Production must set a strong `JWT_SECRET_KEY`, exact `CORS_ORIGINS`, and the Flutter `BOARDMAP_API_URL`.
## Tests and Flutter

Backend: `.venv\Scripts\python.exe -m pytest`. Flutter is in
`../Frontend/boardmap_project`; run `flutter pub get`, `flutter analyze`, `flutter test`,
then `flutter run -d chrome --web-port=5000 --dart-define=BOARDMAP_API_URL=http://127.0.0.1:8000`.
For Android Emulator, use `--dart-define=BOARDMAP_API_URL=http://10.0.2.2:8000` instead
of the browser/desktop loopback address.
