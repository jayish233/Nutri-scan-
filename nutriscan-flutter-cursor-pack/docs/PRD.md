# NutriScan Flutter: Product Requirements

## 1. Summary and scope

NutriScan for Flutter is a photo-first calorie and macro tracker for you and your friends, with real accounts and a backend that keeps the AI key off the phone. It ports the current SwiftUI iOS app to Flutter, starting on Android, and replaces every mock service with a live API that Claude will build to the contract in section 10.

This document has four parts: the product (sections 1-5), the design (6-7), the app architecture (8-9) and the backend contract (10-11). Section 12 holds the build order and open questions. It was written from the repository itself (README, `CLAUDE.md`, `EndpointMap.md`, the Swift models, services and screens), not from the older Android `PRD.md`, which no longer matches the iOS app (section 5).

**In v1**

- Invite-only accounts: register, sign in, restore session, reset password, delete account
- A 4-step onboarding that sets goal, diet, protein ambition and circle opt-in
- Scan a meal photo, review the AI estimate, correct it, confirm, and see totals update
- Today dashboard: energy ring, protein, carbs, fat, fiber, Protein Navigator, meals, streak
- Meal history, weekly charts, manual meal entry, goals, diet preferences, profile, privacy, appearance
- Workouts and accountability circles (streak-only), shipped after the core loop

**Not in v1**

- Public community feed (already hidden from the iOS tab bar)
- Family Thali Scan (removed from iOS; do not reintroduce)
- Apple Health or Health Connect, barcode and voice logging, billing, a web app

**Platform.** Flutter on Android first (minimum SDK 24, as in the repo's Android PRD), with the same code able to build for iOS later. The Swift app stays until the Flutter app reaches parity. This is an assumption; say so if you want iOS first.

**Proposed success measures** (a friends group of roughly 5-30 people, so watch trends, not significance)

| Measure | Proposed target |
| --- | --- |
| Scans confirmed, as a share of scans started | 80% or more |
| Time from opening the app to a logged meal | Under 30 seconds on a good connection |
| Friends still logging 7 days after sign-up | 60% or more |
| AI estimates the user corrected | Tracked, no target |
| AI spend per user per month | Under a cap you set (section 11) |

## 2. Users and journeys

The users are you and the friends you invite: people who want logging a meal to take seconds, with a lean toward Indian home food and vegetarian or eggetarian protein gaps. Nothing about their nutrition is public, and circles share only streaks.

| Role | Who | What they can do |
| --- | --- | --- |
| Member | A friend with an invite code | Everything in the app, on their own data only |
| Admin | You | Creates invite codes, sets scan limits and reads usage through a command-line tool on the server, not an in-app screen |

**Journeys the app must make effortless**

1. **First run.** Welcome, then Create account with an invite code, then the 4-step onboarding, then an empty Summary that points at Scan.
2. **Daily loop.** Open the app, tap Scan, take a photo, wait for the estimate, correct anything off, confirm. The ring, macros, streak and Protein Navigator update immediately.
3. **Returning.** A cold start restores the session behind a splash, never flashing the Welcome screen. If the refresh token has expired, the user lands on Sign in with a short "session expired" message.
4. **Forgot password.** Sign in, Forgot password, enter email, follow the emailed link or code, set a new password, sign in.
5. **Join a friend's circle.** Progress, Circles, type the 6-character code, see each member's streak and whether they logged today.
6. **No connection.** An offline banner shows. Cached days and charts stay readable. Scan and Save explain that they need a connection (offline saving is P1).

## 3. Feature requirements

P0 is the core loop and must ship before friends are invited. P1 follows in the order given in section 12. Each row says when it counts as done. Numbers such as goal ranges and group limits are the ones in the iOS code.

| ID | Requirement | Pri | Done when |
| --- | --- | --- | --- |
| A1 | Register with invite code, display name, email, password, confirm password | P0 | Account created, tokens stored, user lands in onboarding; a used or expired code and a taken email give plain errors |
| A2 | Sign in with email and password | P0 | Wrong credentials show one generic message; success lands on Summary or onboarding |
| A3 | Restore session on cold start with silent token refresh | P0 | No Welcome flash; an expired refresh token returns to Sign in |
| A4 | Sign out on this device | P0 | Tokens and the local cache for that user are cleared |
| A5 | Forgot and reset password by email | P0 | Reset link works once within 1 hour; all other sessions are signed out |
| A6 | Delete account and all data | P0 | Asks for the password, removes rows and photos, returns to Welcome |
| A7 | Change password; sign out of all devices | P1 | Other sessions stop working within the access-token lifetime |
| A8 | Sign in with Google | P1 | Backend verifies the Google ID token and links by verified email |
| O1 | Onboarding: goal mode, diet, protein ambition, circle opt-in | P0 | Goals, diet and sharing flag saved to the server; Skip on step 1 still completes onboarding; not repeated on a new device |
| S1 | Take a photo or pick from the gallery | P0 | JPEG, longest side 1280 px, quality about 0.72, before upload |
| S2 | Server-side AI analysis | P0 | Returns name, items, totals, fiber, allergens, confidence; non-food is rejected with the model's reason and no invented numbers |
| S3 | Review screen | P0 | Shows photo, confidence badge, editable name, meal type, editable calories, protein, carbs, fat, fiber, detected items when there is more than one, allergen banner, estimate disclaimer |
| S4 | Confirm saves once | P0 | A double tap or retry creates one meal; Retake discards the scan |
| S5 | Corrections are recorded | P0 | The correction panel opens by default at medium or low confidence; the meal stores `was_user_corrected` |
| S6 | Daily scan limit | P0 | At the limit the user sees when scans reset, and can still add a meal manually |
| M1 | Manual meal entry | P0 | Name, meal type, calories, protein, carbs, fat, optional notes |
| M2 | Meal detail and delete | P0 | Photo, items, correction note, disclaimer; delete asks for confirmation |
| M3 | Edit a saved meal | P1 | Name, type, macros and notes editable (iOS has no edit today) |
| M4 | History by day | P0 | Week strip and calendar sheet with a ring per day; day total and meals listed |
| M5 | Weekly charts | P0 | Calories, protein and workouts for the last 7 days |
| D1 | Energy ring with remaining calories and goal-mode chip | P0 | Matches the logged total against the target |
| D2 | Protein, carbs, fat and fiber tiles with an intraday sparkline | P0 | Tiles open history |
| D3 | Protein Navigator | P0 | Deterministic rules over the bundled food list; respects diet; never suggests a food the user's restrictions exclude (section 5) |
| D4 | Streak and today status | P0 | Shows days in a row, meals logged today or a workout logged |
| D5 | Pull to refresh, offline banner, cached data | P0 | Summary renders from cache when offline |
| G1 | Goals with three goal modes | P0 | Mode fills suggested targets; calories 1000-5000 (step 50), protein 20-300, carbs 20-600, fat 10-200 (step 5); calories and protein must be above zero |
| W1 | Log and list workouts | P1 | Type, duration (required), distance for cardio, sets for strength, notes; week and month counts |
| C1 | Accountability circles | P1 | Create (up to 10 per person), join by 6-character code, up to 5 members; members see name, streak and whether logged today, nothing else |
| P1 | Edit profile, diet preferences, privacy, appearance | P0 | Name, username, bio; diet restrictions and notes; four privacy toggles; Dark (default), Light or System |
| P2 | Avatar upload | P1 | Resized to 512 px before upload |
| X1 | Save while offline, synced later | P1 | Queued with the same ids so a retry never duplicates |
| X2 | Reminders by push notification | P1 | Opt-in, one daily nudge, no shame wording |

## 4. Authentication and accounts

Sign-up is invite-only with email and password, short-lived access tokens and rotating refresh tokens. Invite-only matters most: every scan costs money, so anyone who can register can spend your AI credits.

| Topic | Decision | Reason |
| --- | --- | --- |
| Sign-up gate | An invite code is required. Codes are created by you from the server's command line, with a use limit and an expiry | Keeps strangers out and caps spend |
| Credentials | Email plus password. Email is stored lowercase. Password is 8 characters or more, checked against a short list of common passwords. No composition rules | iOS accepts 6; 8 is the safer floor |
| Username | Generated unique at sign-up from the display name, editable later as 3-20 characters of a-z, 0-9 and underscore | The iOS mock builds it from the display name, which collides for two people named alike |
| Access token | A JWT valid for 15 minutes, held in memory and in secure storage | Limits damage from a stolen token |
| Refresh token | An opaque random value valid for 30 days, stored hashed on the server, replaced on every use. Reusing an old one revokes that whole session | Detects theft without forcing frequent logins |
| Storage on the phone | `flutter_secure_storage` (Android Keystore). Never `shared_preferences`, never logs | Tokens are credentials |
| Password reset | Emailed single-use link or code valid for 1 hour. The request always answers 202, whether or not the email exists. A successful reset signs out every other session | Prevents account enumeration and takeover |
| Email verification | Off in v1, behind a server switch | Invite codes already gate sign-up |
| Brute force | Sign-in: 5 failed attempts per 15 minutes per account and address, then back-off. Sign-up: 5 per hour per address | Slows guessing |
| Error wording | Sign-in failure says "Email or password is incorrect" and never which one | No account enumeration |
| Account deletion | In the app, behind the password. Removes the user, meals, workouts, goals, circle memberships and photos | Privacy, and a store requirement if you publish |
| Google sign-in | P1. The app sends Google's ID token and the backend verifies it. Apple sign-in is needed only if you publish on the iOS App Store alongside other social logins | Optional convenience for friends |

**Session behaviour in the app**

- The app shows a splash while it reads secure storage and refreshes if needed. It never shows Welcome to a signed-in user.
- A request that returns 401 triggers exactly one refresh shared by all requests in flight, then retries once. If the refresh fails, the app signs the user out and shows Sign in with "Your session expired."
- Sign out clears tokens, the cached profile and the local database for that user, as the iOS `SessionStore.clear()` does today.
- Onboarding completion, goals, diet and privacy flags live on the server, so a new phone does not repeat onboarding.

## 5. Product rules and changes from the iOS app

The product rules come straight from `CLAUDE.md` and carry over unchanged. The changes below are decisions where the current iOS code is a mock, a shortcut or a bug, so the Flutter app should not copy it.

**Rules that stay**

- Nutrition values are editable AI estimates. Always show confidence, the estimate disclaimer and, when present, the allergen warning on scan and meal screens. Never present them as diagnosis or medical advice.
- Circles share a streak count and whether someone logged today. Never calories, weight or body images.
- Protein Navigator is a deterministic rule engine over a bundled food list, not an AI call.
- Nutrition data is private by default. Tone is supportive: no shame wording for treats, festivals or missed days.
- Family Thali Scan stays removed.

**What changes**

| Topic | iOS today | Flutter and backend |
| --- | --- | --- |
| Existing Android `PRD.md` | Describes 5 tabs including Community, older orange, blue and purple colours, no goal modes, onboarding, fiber, allergens or circles | Superseded by this document, which follows the current iOS app |
| AI key | OpenRouter key is read from `Secrets.xcconfig` into the app bundle, so it ships inside the app | Key lives only on the server; the app uploads the photo to `POST /v1/scans` |
| Auth | Mock: any email and a 6-character password works | Real accounts, section 4 |
| Charts, history, streak | Downloads every meal (`allMeals()`) and computes on the phone | Server returns a day summary and daily totals for a date range |
| Streak | Counts back from today, so it reads 0 until the day's first meal | Counts back from today, or from yesterday if nothing is logged yet today, so a morning open still shows the streak |
| Protein Navigator diet filter | Handles vegan, vegetarian, eggetarian and dairy-free only. A nut-free user can be shown roasted peanuts | Add `contains_nuts` and `contains_gluten` to the food list and filter on them; nut-free users never see peanuts |
| Username | Derived from the display name, so two "Asha Rao" collide | Server makes it unique; user can edit it |
| Onboarding done flag and privacy toggles | Stored on the device only | Stored on the server so they follow the account |
| Day boundaries | Uses the phone's calendar each time, so totals can shift if the time zone changes | Each meal stores `local_date` as the phone saw it when logged; totals and streaks group by that |
| Non-food check | An on-device Vision heuristic exists but only the mock path uses it; the real path relies on the model's `is_food` | No on-device classifier; the server validates the model's answer |
| Password minimum | 6 characters | 8 characters |
