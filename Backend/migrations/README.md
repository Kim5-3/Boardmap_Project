The initial revision checks for compatible pre-existing `users`, `boarding_houses`, and
`favorites` columns before creating missing BoardMap tables. If a table has a different
shape, upgrade stops before changing the schema. Review the database and write a
purpose-built data-preserving migration; do not rename, drop, or recreate the table to
make the check pass. Later additive revisions add inquiries/listing images, moderation
history and rejection feedback, contact numbers, profile photo references, and support
reports. The local database is at `0006_issue_reports`; no property records were inserted.
Revision `0006_issue_reports` adds report tickets, user/admin conversations, status history,
and in-app notifications. It is additive and preserves existing rows. Apply it with
`alembic upgrade head` before enabling the report screens. Private report attachments are
stored under `REPORT_UPLOAD_DIR`, outside the publicly served uploads folder; back up that
directory with the database.
