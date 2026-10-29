# NutriScan Backend: Scan Pipeline, Security and Deployment

## 11. Backend: scan pipeline, security, limits and deployment

**Scan pipeline.** This moves the logic in the iOS `OpenRouterFoodAnalysisService` onto the server, so the AI key never ships in the app.

1. Validate the upload: JPEG, PNG or HEIC, at most 4 MB (the app compresses to about 1600 px on the long edge before sending). Otherwise return `payload_too_large` or `validation_failed`.
2. Check the daily quota (default 15 scans per user per day, counted from `scans` by the user's local day in UTC+05:30 unless configured otherwise). Otherwise return `quota_exceeded` with `resets_at`.
3. Strip EXIF (including GPS), re-encode as JPEG, and save to object storage under a random key. The photo is private.
4. Call OpenRouter chat completions with `openai/gpt-4o-mini`, temperature 0.2 and a 45 s timeout. Send the system prompt from the iOS service unchanged to begin with (the `is_food` schema, its rules, and "never present estimates as medical advice"), and record a `prompt_version` on every scan.
5. Parse the reply the way the iOS mapper does: strip markdown fences, take the text from the first `{` to the last `}`, then validate against the schema. Retry once if parsing fails.
6. Apply the mapper rules. If `is_food` is false, return `not_food` with the reason and delete the photo. If `items` is empty, build one item from the totals. If `totals` is missing, sum the items. If the name is missing, use the first item. Clamp confidence to 0-1 and reject negative numbers.
7. Save the `scans` row with `expires_at` 24 hours ahead, and return the Scan result with a signed `image_url`.
8. A cleanup job runs hourly. It deletes unconfirmed scans and their photos once they expire. A confirmed scan's photo moves to the meal and is kept until the meal or the account is deleted.

A failed or `not_food` call still counts toward the quota, so the limit also acts as a cost cap. Provider failures (timeouts, 5xx) do not count, and they return `ai_unavailable`. Log the model, tokens, latency and outcome for every scan, but never the image or the full AI reply at info level.

**Authentication details**

| Topic | Rule |
| --- | --- |
| Passwords | Argon2id, with a minimum of 8 characters and a maximum of 128. Reject the 1,000 most common passwords. This replaces the iOS 6-character minimum |
| Access token | Signed JWT with `sub`, `iat`, `exp` and a token version. Lifetime 15 minutes. Signing key from an environment variable, rotatable |
| Refresh token | 32 random bytes, base64url. Only a SHA-256 hash is stored. Lifetime 30 days (matches PRD section 4) |
| Rotation | Each refresh marks the old token used and issues a new one in the same family |
| Reuse grace | If a used token arrives again within 10 seconds (a lost response or two quick app launches), issue another successor in the same family; only hashes are stored, so the first successor cannot be returned again, and both stay valid until used. After 10 seconds, treat it as theft: revoke the whole family and return `unauthorized` |
| Reset codes | 6 digits, valid for 1 hour (matches PRD A5 and the reset screen copy), 5 attempts, stored hashed. The response never says whether the email exists |
| Sign-up | Open: no invite code. Spend is capped by the per-user daily scan quota and the register rate limit (5 per hour per IP) |
| Username | Derived from the display name plus a short random suffix, so two people called "Aarav" never collide (the iOS app did collide) |

**Rate limits** (per IP unless stated; counters kept in memory for one server, in Redis if you scale out)

| Route | Limit |
| --- | --- |
| `/auth/login` | 10 per 15 minutes per IP and 5 failed attempts per email per 15 minutes |
| `/auth/register` | 5 per hour |
| `/auth/password/forgot` | 3 per hour per email, 10 per hour per IP |
| `/scans` | 6 per minute per user, plus the daily quota |
| Everything else | 120 per minute per user |

**Other security rules**

- HTTPS only, with HSTS. Reject plain HTTP in production.
- Every query is filtered by the caller's `user_id`. A request for someone else's item returns `not_found`.
- Photos are never public. `image_url` is a signed link that expires in 1 hour; the app re-fetches the meal when it needs a fresh one.
- Request bodies are limited (1 MB for JSON, 4 MB for photos). CORS is off because the client is a mobile app.
- Logs carry a request id, user id, route, status and latency. They never include passwords, tokens, reset codes or the contents of meals.
- Secrets (`JWT_SECRET`, `OPENROUTER_API_KEY`, database and storage credentials, email key) come from environment variables or the host's secret store, never from the repository.
- Set a monthly spend limit on the OpenRouter key and alert at 80%.

**Email.** Reset codes need transactional email. Use a provider with a free tier (Resend, Brevo or Amazon SES) from a domain you own. Because the group is small, an acceptable fallback for launch is for the admin command to print a reset code that you pass to a friend yourself.

**Admin command line.** A single `nutriscan-admin` tool runs on the server and needs no web admin screen.

| Command | Purpose |
| --- | --- |
| `user list`, `user disable <email>` | See and block accounts |
| `user reset-password <email>` | Prints a one-time reset code |
| `scan stats --days 7` | Scan counts, failures and estimated spend |

**Deployment**

| Piece | Choice for a friends-only launch |
| --- | --- |
| Runtime | One container, built from a Dockerfile, behind a reverse proxy with automatic TLS (Caddy or the host's own) |
| Database | Postgres 16. A managed instance is best; a container with a daily dump is acceptable |
| Object storage | Any S3-compatible bucket (Cloudflare R2, Backblaze B2 or S3). Private, with a lifecycle rule for deleted keys |
| Hosting | A small VM or container host. Pick a region close to India (Mumbai or Singapore) to keep scan latency low |
| Migrations | Run at start-up with a versioned tool; each migration is reversible |
| Backups | Nightly database backup kept for 14 days, and a restore test before the first friend signs up |
| Config | `DATABASE_URL`, `JWT_SECRET`, `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`, `STORAGE_*`, `EMAIL_*`, `SCAN_DAILY_LIMIT`, `PUBLIC_BASE_URL` |
| Monitoring | `/healthz` and `/readyz` checked by an uptime service, with error alerts by email |

**Backend tests.** The suite must cover: register and a taken email; login failure counts; refresh rotation, the 10 s grace and reuse revocation; every route rejecting another user's ids; PUT idempotency (the same body twice gives one row); `local_date` grouping around midnight; summary and streak maths (including the morning grace rule); scan parsing with fenced JSON, bad JSON, `is_food: false`, missing totals and empty items, using a fake AI client; quota counting; photo clean-up after expiry; and contract tests that check every response against `openapi.yaml`. Real OpenRouter calls are only made in a manual smoke test.
