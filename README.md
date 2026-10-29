# NutriScan

Photo-first calorie and macro tracker for a small group of friends. Flutter app (Android first) plus a FastAPI backend that holds the AI key. Specs: `PRD.md`, `DESIGN.md`, `ARCHITECTURE.md`, `API_CONTRACT.md`, `BACKEND.md`, `BUILD_PLAN.md`.

## Run it locally

```bash
# 1. Backend (Postgres in Docker)
OPENROUTER_API_KEY=sk-or-... docker compose up --build

# 2. App on the Android emulator (talks to http://10.0.2.2:8000)
flutter run --dart-define-from-file=config/dev.json
```

Without Docker, the backend also runs on SQLite:

```bash
cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt -r requirements-dev.txt
OPENROUTER_API_KEY=sk-or-... .venv/bin/uvicorn app.main:app --port 8000
```

For a real phone, set `PUBLIC_BASE_URL` on the server and `API_BASE_URL` in `config/*.json` to an address the phone can reach. Release builds require `https://`.

## Checks

```bash
flutter analyze && flutter test && dart format --set-exit-if-changed lib test
cd backend && .venv/bin/python -m pytest -q
```

`contracts/openapi.yaml` is generated from the API (`cd backend && .venv/bin/python -m scripts.export_openapi`); a backend test fails if it drifts.

## Admin

`python -m app.admin` on the server: `allow add|list|remove <email>` (the Neon Auth invite list — only allowlisted emails can use the API), `user list|disable|reset-password <email>`, `scan stats --days 7`, `doctor` (checks Postgres and the deployed function). Until an email provider is set (`EMAIL_RESEND_API_KEY`, `EMAIL_FROM`), use `user reset-password` to print a reset code for a friend.

## Auth

Sign-in runs through Neon Auth (Managed Better Auth): the app authenticates against `NEON_AUTH_BASE_URL` and sends the signed session value as its Bearer credential; the API validates it via `/get-session` and gates on the `allowed_emails` list. Legacy `/v1/auth/*` endpoints stay live during the migration.

## Production config

`ENV=prod`, `DATABASE_URL`, `JWT_SECRET` (32+ random bytes), `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`, `PUBLIC_BASE_URL` (https), `STORAGE_DIR` (a backed-up volume), `SCAN_DAILY_LIMIT`. Put the API behind a TLS proxy (Caddy) and set an OpenRouter spend limit.
