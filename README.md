# BoardMap

BoardMap is a Flutter app for finding boarding houses in Cabadbaran City. It uses a
versioned FastAPI service and PostgreSQL for accounts, listings, and favorites.

## Project layout

- `Frontend/boardmap_project/` — Flutter app and widget tests.
- `Backend/` — FastAPI, SQLAlchemy models, Alembic migrations, and pytest tests.
- `Backend/README.md` — Windows setup, environment, and API details.

## Run the backend on Windows

```powershell
cd Backend
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

Set the PostgreSQL `DATABASE_URL` and a random `JWT_SECRET_KEY` (at least 32 characters)
in `Backend/.env`. Create the database and application user first. The migration checks
existing same-named tables and stops if their structure is incompatible; it does not
drop or recreate legacy data. Review `Backend/migrations/README.md` before migrating.

```powershell
alembic upgrade head
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Open the API docs at `http://127.0.0.1:8000/docs`, process health at `/health`, and
database readiness at `/ready`.

## Run Flutter Web

In another PowerShell window:

```powershell
cd Frontend/boardmap_project
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port=5000 --dart-define=BOARDMAP_API_URL=http://127.0.0.1:8000
```

For Android Emulator, use `--dart-define=BOARDMAP_API_URL=http://10.0.2.2:8000`.
For production, pass the actual deployed API URL through `BOARDMAP_API_URL` at build/run
time; no production URL is configured in this repository. Add the exact frontend origin to
the backend's `CORS_ORIGINS`. No sample listings, prices, or property coordinates are
bundled as real data; renter listings and map markers come from active database records.

## Implemented baseline and current limits

Registration and login use Argon2 password hashes and short-lived JWTs. Users can sign in
with email; registration generates a username when none is supplied. Owners can manage only
their own listings. New listings enter Pending review, and only administrators can approve
or reject them. Rejections require a reason and create a moderation history record. Public
search and map show approved listings; map pins require valid coordinates. Full approved
listings remain visible with a clear full status. Recommendations rank available places
first and can include full places lower in the results, with the reason shown, so renters
can still compare them. Search controls support price range, room type, amenities, and
sorting. The room-type selector includes common choices plus types entered by owners.

Renter inquiries and owner responses are backed by PostgreSQL. Listing images and profile
photos are validated and stored as files, not database blobs. Recommendations use the
backend Scikit-learn KNN ordering across approved listings when there is enough data; the
API explains its fallback when there is not enough data to compare. The landing page reads actual approved
records and shows a clear empty state when none exist. Theme choice persists in browser
local storage. In-app issue reports support renter and owner submissions, private image
attachments, report tracking, admin review, status history, conversation replies, and
database-backed notifications. Report files are stored outside the public uploads directory.
Email/push notifications and listing-view analytics are not implemented.

The administrator dashboard shows pending listing and issue-report review counts, provides
shortcuts into those queues, and displays a paginated activity log from listing and report
moderation histories. Account types are informational and cannot be changed in the admin UI
or through the role-update API.

The local PostgreSQL database is at Alembic revision `0006_issue_reports`. It intentionally
has no boarding-house listings; no property records were invented or inserted. Before a live
demo, add real, reviewed properties through the owner workflow and have an administrator
approve them. Verify each address, availability count, amenities, photos, and coordinates.

No production API URL exists yet. Before deployment, set the HTTPS Flutter
`BOARDMAP_API_URL`, list the exact deployed web origin in backend `CORS_ORIGINS`, disable
the development CORS regex, and set production database/JWT secrets outside source control.
Confirm PostgreSQL backups and private report-upload storage are included in deployment.
Browser verification of OSM tiles, marker selection, sign-in, search, and responsive layouts
remains necessary against the actual deployment.
