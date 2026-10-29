# NutriScan: Build Plan, Testing and Open Questions

## 12. Build plan, testing, assumptions and open questions

**Build plan.** The backend and the app are built in parallel against the contract. Each phase ends with something a friend could try.

| Phase | Backend | Flutter app | Done when |
| --- | --- | --- | --- |
| 0. Contract | Write `contracts/openapi.yaml` from section 10; pick the stack; set up the repo, CI and a Docker Compose file with Postgres | Create the project, theme tokens (section 6), router skeleton and a mock API client generated from the contract | Both sides agree on the contract and the app runs against mocks |
| 1. Accounts | Register, login, refresh, logout, reset, `/me` and the admin command line | Splash, sign-in, sign-up, reset flow, secure token storage, single-flight refresh | You can invite a friend, and they can sign in on a real phone |
| 2. Scan loop | `POST /scans`, meals, goals, summary, photo storage and clean-up | Onboarding, scanner, result and edit screen, Summary with rings, meal list and delete | A friend scans a thali, edits it, confirms it, and the rings move |
| 3. Tracking | `/stats/daily`, workouts, streak maths, quota endpoint | Progress charts, calendar, history, workouts, Protein Navigator, profile and goals | Every iOS tab has a working equivalent |
| 4. Circles | Circle routes and the sharing rules | Circles screen, join and leave, streak-only members | Two friends see each other's streaks and nothing else |
| 5. Hardening | Rate limits, backups, monitoring, spend alert, account deletion | Offline read cache, retry queue for meal writes, accessibility pass, release build and signing | A written release checklist passes, and the restore test has been run |

Phases 1 and 2 are the minimum to let friends use the app. Phases 3 to 5 can ship as updates.

**App testing**

- `flutter analyze` and `dart format --set-exit-if-changed` on every push.
- Unit tests: calorie and macro maths, confidence labels (0.75 and 0.45 thresholds), the streak display, the Protein Navigator (including the nut-free fix), JSON models, and the refresh interceptor (two simultaneous 401s cause one refresh).
- Widget tests with golden images for the ring, cards, banners and the tab bar, in dark and light, at large text size.
- Integration test on an emulator against the real backend in Docker Compose: sign up, scan with a fixture photo and a fake AI client, confirm, see the totals, sign out and back in.
- Contract test: the generated API client is rebuilt from `openapi.yaml` in CI, and the build fails if the app and the file disagree.
- Manual device check before each release: low-end Android phone, airplane mode, a slow network, and a denied camera permission.

**Assumptions**

- Android is the first target (your friends' phones), with iOS support following from the same Flutter code.
- The group is small, so there are no payments or ads. Sign-up is open (no invite code).
- The backend is built by Claude from this document. Backend language and framework are not fixed yet; the contract does not depend on them.
- OpenRouter with `openai/gpt-4o-mini` stays the vision model. Changing it only touches the server.
- The AI result is an estimate. The app keeps the disclaimer, the allergen banner and the edit step.
- Family Thali Scan stays out, as in the iOS app. The community feed is out of scope.
- Data is private by default, and circles only share streaks and whether someone logged today.
- Old iOS test data is not migrated. Friends start fresh.

**Open questions** (each has a default, so none blocks Phase 0)

| Question | Default if you do not decide |
| --- | --- |
| Backend stack | Python with FastAPI, because it makes the OpenAPI file and tests easy to keep in step. Go or Node are equally possible |
| Where it will be hosted, and the monthly budget | A small VM in a Mumbai or Singapore region plus managed Postgres |
| Email provider for reset codes | Resend, or the admin-printed code at first |
| Google sign-in | Not in the first release (P1) |
| Daily scan limit | 15 per person |
| Offline logging | Read cache in Phase 5; queued writes only if friends often log without signal |
| Will the iOS app also move to this backend? | Yes, later, since the contract is the same |
