# NutriScan Flutter: App Architecture

## 8. Architecture: system and app structure

One Flutter app talks to one JSON API over HTTPS. The API owns accounts, data, photos and the AI key, so nothing secret ships inside the app. The diagram below shows the parts; sections 10 and 11 define the API.

**Repository.** `EndpointMap.md` says the Go stub lives at `apps/api` in the separate `nutriscan` repo (branch `feat/api`). The recommendation is to keep the app and API together there: the Flutter app in `apps/mobile` and the API contract in `contracts/openapi.yaml`, so a contract change and the code that uses it land in one commit. The existing iOS repo stays as the behaviour reference until the Flutter app reaches parity.

**Layers.** Each feature has three layers, which map to what the iOS app does with protocol services and mocks.

| Layer | Holds | iOS equivalent |
| --- | --- | --- |
| Presentation | Widgets and one Riverpod notifier per screen. Widgets never call the network | SwiftUI views and view models |
| Domain | Plain Dart models, repository interfaces, and pure logic: goal modes, confidence levels, streaks, Protein Navigator | `DomainModels.swift`, `*ServiceProtocol` |
| Data | Dio API clients, Drift tables, and repository implementations that read the cache and refresh from the API | `Live*Service`, `LocalCache` |

A fake repository per feature replaces the old mocks. Tests and early UI work override the real repositories with fakes through Riverpod, which is the job `AppDependencies` does on iOS.

**Packages.** Each one earns its place; pin exact versions when scaffolding.

| Concern | Package | Why |
| --- | --- | --- |
| State and wiring | `flutter_riverpod` | `AsyncNotifier` maps to the idle, loading, loaded, empty and error states every iOS screen uses; easy overrides in tests |
| Routing | `go_router` | Auth redirect and a shell route that keeps each tab's stack |
| HTTP | `dio` | Interceptors for the auth header and token refresh, multipart upload with progress |
| Token storage | `flutter_secure_storage` | Android Keystore-backed |
| Small settings | `shared_preferences` | Theme choice, last tab, cached profile |
| Local database | `drift` with `sqlite3_flutter_libs` | Date-range queries for history and charts while offline; one file per user |
| Photos | `image_picker`, `flutter_image_compress`, `cached_network_image` | System camera and gallery, JPEG compression, thumbnail cache |
| Charts | `fl_chart` | Bar charts and tile sparklines |
| Connectivity | `connectivity_plus` | Offline banner |
| JSON models | `json_annotation`, `json_serializable`, `build_runner` | Plain generated code, no heavier model framework |
| Ids | `uuid` | Client-made ids make retries safe |
| Tests | `flutter_test`, `mocktail`, `integration_test` | Unit, widget and end-to-end |

The rings need no package; draw them with a `CustomPainter`. Bundle the Inter font in the app instead of fetching it at run time. The iOS app has no custom camera screen, so `image_picker` replaces the `camera` package the older plan suggested.

**Folder layout**

```
apps/mobile/
  lib/
    main.dart
    app/         app.dart, router.dart, providers.dart, config.dart, theme/
    core/        api/ (dio client, interceptors, api_error)
                 storage/ (secure store, prefs, drift db)
                 widgets/ (rings, cards, buttons, banners, states)
                 util/ (local_date, image_prep, formatters)
    features/
      auth/        splash, welcome, sign_in, register, forgot, reset
      onboarding/
      summary/
      scan/        picker, analysing, review, error
      meals/       detail, add_manual, history
      goals/
      progress/    weekly_charts, hub
      workouts/
      circles/
      profile/     edit, diet, privacy, appearance
  assets/        fonts/, data/protein_foods.json
  test/  integration_test/
  pubspec.yaml
```

**Pure logic to port first, each with unit tests**

- `GoalMode.suggestedTargets` and the protein-ambition formula
- Confidence levels: 0.75 or more high, 0.45 to below 0.75 medium, below 0.45 low
- Nutrition totals as the sum of items
- Streak with the morning grace described in section 5
- Protein Navigator over `protein_foods.json`, including the nut-free fix
- The local-date key used for grouping

**Configuration.** Flavors `dev` and `prod`, each loading `config/<flavor>.json` through `--dart-define-from-file`. The only value is `API_BASE_URL`: `http://10.0.2.2:8000` for the Android emulator in dev and an `https://` address in prod. There are no secrets in the app, and a release build refuses plain HTTP.

## 9. Architecture: session, networking, storage and scan flow

**Session.** A `SessionController` (a Riverpod notifier) holds one of four states: booting, signed out, needs onboarding, or signed in. The router reads it for every redirect.

- **Boot.** Read both tokens from secure storage. If they exist, treat the user as signed in using the cached profile, so there is no flash of Welcome, and refresh in the background. A 401 from the refresh call signs the user out with "Your session expired."
- **Refresh without a stampede.** An interceptor adds the Bearer token. On a 401 from any non-auth route it starts one refresh that every waiting request shares, saves the new tokens to secure storage first, then retries each request once.
- **Crash safety.** Refresh tokens rotate on every use. If the app dies after the server rotates but before it saves, the old token would look stolen. The backend therefore accepts the just-replaced token again for 10 seconds and returns the same successor (section 10).
- **Sign out.** Call `POST /v1/auth/logout` on a best-effort basis, then clear secure storage, preferences, the user's Drift file and cached images.
- **Android backup.** Set `android:allowBackup="false"` so a restored backup cannot bring back token files the new device cannot decrypt.

**Networking.** One Dio client reads the base URL from config and sends JSON.

| Setting | Value |
| --- | --- |
| Timeouts | Connect 10 s, receive 30 s; scan upload and response 60 s, matching what iOS allows OpenRouter |
| Retries | `GET` retried up to 2 times with back-off on a network error or 5xx. A `PUT` is safe to retry because the id is in the path. A scan `POST` is never retried automatically |
| Errors | Every failure becomes one sealed `ApiError`: unauthorized, forbidden, notFound, validation (message and field errors), conflict, notFood, rateLimited, quotaExceeded (with reset time), server, network, cancelled, decoding. These extend the iOS `APIError` cases |
| Logging | Debug builds only; never tokens, passwords or image bytes |
| Wire format | JSON in `snake_case`, ISO-8601 UTC timestamps, plain `YYYY-MM-DD` for local dates |

**Storage and offline.** The server is the source of truth. Drift holds a per-user cache of meals, workouts, goals, the profile and daily totals. Repositories return the cache first and refresh from the API behind it, so screens paint at once and the offline banner explains stale data. Summary offline is computed from cached meals for today's local date.

Writes need a connection in v1: Save buttons say "You're offline. Connect to save." The API is already shaped for the P1 offline queue. Meals and workouts are written with `PUT /v1/meals/{id}` and `PUT /v1/workouts/{id}`, where the client makes the id, so replaying a queued write can never duplicate it. A later `pending_ops` table in Drift holds the queue.

Photos live in object storage. API responses carry a short-lived signed `image_url`; thumbnails are cached under the meal id so a changing URL does not defeat the cache. The review screen shows the photo from memory and never downloads it again.

**Scan flow.** The app compresses the photo and uploads it once. The server does the AI call and returns an editable analysis, and nothing becomes a meal until the user confirms.

&#91;embedded content: scan flow · 6 steps\]
