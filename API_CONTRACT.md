# NutriScan Backend: Data Model and API Contract

## 10. Backend: data model and API contract

The backend is one versioned REST API under `/v1`, speaking JSON with bearer-token auth, backed by Postgres for data and S3-compatible object storage for photos. The Flutter app is built against the contract below, and `contracts/openapi.yaml` must be kept in step with it. The backend language is not fixed by this contract (section 12 asks you to choose).

**Conventions**

| Topic | Rule |
| --- | --- |
| Auth | `Authorization: Bearer <access token>` on everything except the auth routes and health checks |
| Ids | UUID strings. The client makes the id for meals and workouts |
| Time | UTC ISO-8601 for instants. `local_date` is `YYYY-MM-DD` as the phone saw it when the item was logged |
| Units | kcal, grams, minutes, kilometres, kilograms. Decimals allowed, stored to 1 decimal place |
| Bodies | JSON in `snake_case`; photo uploads use `multipart/form-data` |
| Lists | Cursor pagination: `limit` (default 50, max 200) and `cursor`, returning `{ "items": [...], "next_cursor": null }` |
| Changes | Additive only within `/v1` |

**Errors.** Every failure has this shape, and the app maps `code` to its message and behaviour.

```json
{ "error": { "code": "validation_failed", "message": "Calories must be 0 or more.", "fields": { "nutrition.calories": "must be >= 0" }, "request_id": "01J9Z..." } }
```

| Code | HTTP | Meaning and app behaviour |
| --- | --- | --- |
| `invalid_credentials` | 401 | Wrong email or password. Show "Email or password is incorrect." |
| `unauthorized` | 401 | Missing or expired access token. Refresh once, else sign out |
| `forbidden` | 403 | Not allowed, for example another user's item |
| `not_found` | 404 | Missing, or not the caller's. Never reveals which |
| `validation_failed` | 422 | Bad input; `fields` names the problems |
| `conflict` | 409 | Email or username already taken; `fields` says which |
| `not_food` | 422 | The photo is not food; `message` is the model's reason |
| `rate_limited` | 429 | Too many requests; `Retry-After` header in seconds |
| `quota_exceeded` | 429 | Daily scan limit reached; body includes `reset_at` |
| `payload_too_large` | 413 | Photo over the size limit |
| `ai_unavailable` | 503 | The AI provider failed or timed out; safe to retry later |
| `server_error` | 500 | Anything else |

**Tables**

| Table | Main columns | Notes |
| --- | --- | --- |
| `users` | `id`, `email` (unique, lowercase), `password_hash`, `display_name`, `username` (unique), `bio`, `avatar_key`, `dietary_restrictions` (text array), `dietary_notes`, `streak_sharing`, `profile_public`, `nutrition_visible`, `workouts_visible`, `onboarding_completed`, `created_at` | The three visibility flags are stored now and used by the later community feature |
| `refresh_tokens` | `id`, `user_id`, `family_id`, `token_hash`, `expires_at`, `used_at`, `replaced_by`, `revoked_at`, `device_name` | One family per sign-in |
| `password_resets` | `user_id`, `code_hash`, `expires_at`, `attempts`, `used_at` | Single use |
| `goals` | `user_id` (key), `mode`, `calorie_target`, `protein_target`, `carbohydrate_target`, `fat_target` | A row is created at sign-up with the Maintenance defaults |
| `scans` | `id`, `user_id`, `image_key`, `status`, `result` (JSON), `model`, `prompt_version`, `latency_ms`, token counts, `created_at`, `expires_at`, `meal_id` | The daily quota is counted from here |
| `meals` | `id`, `user_id`, `name`, `meal_type`, `logged_at`, `local_date`, `calories`, `protein`, `carbohydrates`, `fat`, `fiber`, `items` (JSON), `notes`, `was_user_corrected`, `image_key`, `scan_id`, `created_at`, `updated_at` | Index on (`user_id`, `local_date`) |
| `workouts` | `id`, `user_id`, `type`, `title`, `duration_minutes`, `distance_km`, `exercises` (JSON), `notes`, `logged_at`, `local_date` | Index on (`user_id`, `local_date`) |
| `circles` | `id`, `name`, `invite_code` (unique), `created_by`, `created_at` |  |
| `circle_members` | `circle_id`, `user_id`, `joined_at` | Key on both columns |

**Shared shapes**

```json
// Nutrition (fiber optional)
{ "calories": 420, "protein": 18, "carbohydrates": 55, "fat": 12, "fiber": 6 }

// Item inside a scan or meal
{ "id": "uuid", "name": "Dal", "serving": "1 cup", "nutrition": { ... }, "confidence": 0.82 }

// Scan result: returned by POST /v1/scans
{ "id": "uuid", "recognized_name": "Dal and rice", "confidence": 0.78,
  "items": [ ... ], "total": { ... }, "potential_allergens": ["milk"],
  "image_url": "https://...", "analyzed_at": "2026-10-27T07:35:00Z", "expires_at": "2026-10-28T07:35:00Z" }

// Meal
{ "id": "uuid", "name": "Dal and rice", "meal_type": "lunch", "logged_at": "2026-10-27T07:36:10Z",
  "local_date": "2026-10-27", "nutrition": { ... }, "items": [ ... ], "notes": null,
  "was_user_corrected": false, "image_url": "https://...", "scan_id": "uuid" }
```

**Auth and account endpoints**

Sign-in is migrating to **Neon Auth** (Managed Better Auth): the app signs up and signs in against `NEON_AUTH_BASE_URL` directly (`/sign-up/email`, `/sign-in/email`, `/sign-out`, `/request-password-reset`) and sends the signed session cookie value as `Authorization: Bearer` to this API. The API validates it by replaying it to `{NEON_AUTH_BASE_URL}/get-session`, requires the email to be on the `allowed_emails` invite list (`403 forbidden` otherwise), and provisions the local user on first use. The legacy `/v1/auth/*` endpoints below stay live during the migration so existing tokens keep working; `DELETE /v1/me` skips the password check for Neon-provisioned accounts (empty `password_hash`).

| Method and path | Auth | Request | Success | Notes |
| --- | --- | --- | --- | --- |
| `POST /v1/auth/register` | none | `email`, `password`, `display_name` | 201 `{ user, tokens }` | Legacy local sign-up (no invite code). New accounts use Neon Auth instead |
| `POST /v1/auth/login` | none | `email`, `password`, `device_name?` | 200 `{ user, tokens }` | `tokens` is `{ access_token, refresh_token, expires_in }` with `expires_in` = 900 |
| `POST /v1/auth/refresh` | none | `refresh_token` | 200 `{ tokens }` | Rotates. See the reuse rule in section 11 |
| `POST /v1/auth/logout` | bearer | `refresh_token` | 204 | Revokes that session family |
| `POST /v1/auth/logout-all` | bearer | none | 204 | Revokes every session (P1 in the app) |
| `POST /v1/auth/password/forgot` | none | `email` | 202 | Always 202; emails a code if the account exists |
| `POST /v1/auth/password/reset` | none | `email`, `code`, `new_password` | 204 | Revokes every session |
| `POST /v1/auth/password/change` | bearer | `current_password`, `new_password` | 204 | Revokes other sessions |
| `POST /v1/auth/google` | none | `id_token` | 200 `{ user, tokens }` | P1 |
| `GET /v1/me` | bearer | none | 200 User | User holds profile, diet, privacy flags and `onboarding_completed` |
| `PATCH /v1/me` | bearer | any of `display_name`, `username`, `bio`, `dietary_restrictions`, `dietary_notes`, `privacy`, `onboarding_completed` | 200 User | `409 conflict` for a taken username |
| `PUT /v1/me/avatar` | bearer | multipart `image` (2 MB max) | 200 User | `DELETE /v1/me/avatar` returns 204 |
| `DELETE /v1/me` | bearer | `password` | 204 | Deletes all rows and stored photos |

**Goals, scans and meals**

| Method and path | Request | Success | Notes |
| --- | --- | --- | --- |
| `GET /v1/goals` | none | `{ mode, calorie_target, protein_target, carbohydrate_target, fat_target }` |  |
| `PUT /v1/goals` | the same object | 200 | Calories and protein above 0; sanity ceilings of 10000 kcal, 600 g protein, 1000 g carbs, 400 g fat |
| `POST /v1/scans` | multipart `image` | 201 Scan result | Errors: `not_food`, `quota_exceeded`, `payload_too_large`, `ai_unavailable`. Pipeline in section 11 |
| `GET /v1/scans/quota` | none | `{ limit, used, resets_at }` | Lets the app say "N scans left today" (P1) |
| `DELETE /v1/scans/{id}` | none | 204 | Called on Retake so the photo is removed at once |
| `PUT /v1/meals/{id}` | `name`, `meal_type`, `logged_at`, `local_date`, `nutrition`, `items?`, `notes?`, `was_user_corrected`, `scan_id?` | 201 created or 200 replaced, with the Meal | Idempotent. With `scan_id`, the scan must be the caller's and unexpired; its photo becomes the meal's photo and the scan is marked confirmed |
| `GET /v1/meals` | `date=YYYY-MM-DD` or `from`, `to`, `limit`, `cursor` | List of Meals, newest first |  |
| `GET /v1/meals/{id}` | none | Meal |  |
| `DELETE /v1/meals/{id}` | none | 204 | Also deletes the photo |

**Summary, workouts and circles**

| Method and path | Request | Success | Notes |
| --- | --- | --- | --- |
| `GET /v1/summary` | `date=YYYY-MM-DD` | `{ date, totals, goals, meals, meals_logged, workout_logged, streak_days }` | One call fills Summary. `streak_days` uses the morning grace rule in section 5 |
| `GET /v1/stats/daily` | `from`, `to` (92 days max) | `{ days: [{ date, calories, protein, carbohydrates, fat, fiber, meal_count, workout_count }] }` | Feeds the weekly charts, week strip and calendar rings |
| `PUT /v1/workouts/{id}` | `type`, `title`, `duration_minutes` (above 0), `distance_km?`, `exercises?`, `notes?`, `logged_at`, `local_date` | 201 or 200 Workout | Idempotent |
| `GET /v1/workouts` | `from`, `to`, `limit`, `cursor` | List of Workouts |  |
| `DELETE /v1/workouts/{id}` | none | 204 |  |
| `GET /v1/circles` | `date=YYYY-MM-DD?` (the caller's local date; defaults to today in the server's quota timezone) | `{ items: [Circle] }` | A Circle is `{ id, name, invite_code, created_at, members }`. A member is `{ user_id, display_name, current_streak_days, logged_today, sharing }`. If `sharing` is false both `current_streak_days` and `logged_today` are null. Members are sorted logged-today first, then by streak |
| `POST /v1/circles` | `name` (1-40 characters) | 201 Circle | Up to 10 circles per person (`conflict` past that). The code is 6 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` |
| `POST /v1/circles/join` | `invite_code` (case and spaces ignored) | 200 Circle | Up to 5 members (`conflict` "This circle is full (max 5 members)."); joining twice is a no-op; a malformed code is `validation_failed`; an unknown code is `not_found` |
| `POST /v1/circles/{id}/leave` | none | 204 | The last member leaving deletes the circle. Not a member is `not_found`. Deleting an account leaves all its circles the same way |
| `GET /healthz`, `GET /readyz` | none | 200 | Liveness, and a database check |
