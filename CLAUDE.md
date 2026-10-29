# NutriScan (Flutter + backend)

Photo-first calorie and macro tracker for a small group of friends. Flutter app (Android first) plus a backend that proxies the AI vision call. Ported from the SwiftUI iOS app (github.com/Nutriscan-io/APP-nutri-Scan-).

## Read first

| File | What it holds |
| --- | --- |
| [docs/PRD.md](docs/PRD.md) | Scope, users, features, authentication, product rules, changes from iOS |
| [docs/DESIGN.md](docs/DESIGN.md) | Design tokens, components, navigation and screens |
| [docs/DESIGN_SCREENS.md](docs/DESIGN_SCREENS.md) | Brand, platform chrome and the mockup screens (logo files in `assets/brand/`) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Flutter structure, session, networking, storage, scan flow |
| [docs/API_CONTRACT.md](docs/API_CONTRACT.md) | Data model and every endpoint: the source of truth for app and server |
| [docs/BACKEND.md](docs/BACKEND.md) | Scan pipeline, security, rate limits, deployment, backend tests |
| [docs/BUILD_PLAN.md](docs/BUILD_PLAN.md) | Phases, testing, assumptions, open questions |

## Working rules

- The API contract is the source of truth. Change `docs/API_CONTRACT.md` and `contracts/openapi.yaml` first, then the code. Changes inside `/v1` are additive only.
- The AI key lives only on the server. Never put an OpenRouter key, JWT secret or any credential in the Flutter app or the repository.
- AI nutrition values are editable estimates. Always show confidence, the estimate disclaimer and the allergen banner. Never present them as medical advice.
- Circles share only streak and whether someone logged today. Never calories, weight or photos.
- Protein Navigator is a deterministic rule engine over `IndianProteinFoods.json`; dietary restrictions (including nut-free) must filter it.
- No Family Thali Scan and no community feed.
- Tone is supportive. No shame around festivals, treats or missed goals.
- Writes use PUT with a client-made UUID so they are idempotent. Group by `local_date`.
- Every backend query is filtered by the caller's `user_id`; another user's item returns `not_found`.

## Stack

Flutter, Riverpod, go_router, Dio (single-flight token refresh), Drift, flutter_secure_storage. Backend stack is an open question (default: FastAPI, Postgres, S3-compatible storage); see `docs/BUILD_PLAN.md`.

## Commands

```bash
flutter analyze && flutter test && dart format --set-exit-if-changed lib test
cd backend && .venv/bin/python -m pytest -q
cd backend && .venv/bin/python -m scripts.export_openapi   # after any API change; a test checks contracts/openapi.yaml
flutter run --dart-define-from-file=config/dev.json
```

Layout: Flutter app at the repo root (`lib/`, `test/`), FastAPI backend in `backend/`, generated contract in `contracts/openapi.yaml`.

## Build order

Follow the phases in `docs/BUILD_PLAN.md`: contract, accounts, scan loop, tracking, circles, hardening. Phases 1 and 2 are the minimum for friends to use the app.
