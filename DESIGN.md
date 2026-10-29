# NutriScan Flutter: Design

## 6. Design foundations

The Flutter app follows the design pack in `nutriscan-flutter-cursor-pack/` (`docs/DESIGN_SCREENS.md` and `lib/core/theme/app_tokens.dart`), with the brand files in `assets/brand/`: a pure black canvas, lime for actions, five fixed metric colours, pill buttons and heavy rounded rings. The code reads every value from `lib/app/theme.dart`. Screen layouts and platform chrome are in [DESIGN_SCREENS.md](DESIGN_SCREENS.md). The colours in the older Android `PRD.md` are out of date and should not be used.

**Colour**

| Token | Dark | Light | Used for |
| --- | --- | --- | --- |
| canvas | `#000000` | `#F2F2F7` | App background |
| card | `#1C1C1E` | `#FFFFFF` | Cards, tiles, Android navigation bar |
| cardElevated (raised) | `#2C2C2E` | `#E5E5EA` | iOS tab bar, pills, chips, round buttons, empty chart stubs |
| primaryText | `#FFFFFF` | `#000000` | Main text |
| secondaryText | `#A1A1A6` | `#6B6B70` | Captions, helper text |
| hairline | `#3A3A3C` | black at 10% | Dividers, iOS field borders |
| outline | `#636366` | same | Android outlined fields and buttons |
| brand (lime) | `#C9FF3D` | `#C9FF3D` | Primary buttons, active tab, highlights, today |
| brandDeep | `#C9FF3D` | `#446600` | Lime text and focus borders on a light surface |
| ink | `#000000` | `#000000` | Text and icons sitting on lime |
| energy (calories) | `#FA114F` | same | Hero ring, kcal values |
| protein | `#BF5AF2` | same | Protein values and tiles |
| carbs | `#FFD60A` | same | Carb values, offline banner |
| fat | `#64D2FF` | same | Fat values and tiles |
| fiber, success | `#30D158` | same | Fiber values, "Logged today", confirmations |

A ring or bar track is its metric colour at 22% opacity. A metric colour is never swapped for the brand colour. Dark is the default theme; Profile also offers Light and System. Sign-in and onboarding are always dark.

**Spacing and shape**

| Token | Value |
| --- | --- |
| Spacing | 4, 8, 12, 16, 24, 32, 48. Page padding 16, auth screens 24 |
| Corner radius | Card: iOS 22, Android 28. Tile: iOS 18, Android 20. Field: iOS 14, Android 12. 10 for thumbnails, full pill for buttons, chips and the iOS tab bar |
| Touch target | 48 dp minimum (iOS uses 44 pt) |
| Scroll bottom inset | 108 dp so the floating tab bar and the Android FAB never cover the last row |

Platform is chosen with `isCupertino(context)` (`Theme.of(context).platform`), never with separate screen files.

**Type.** Inter 400, 600, 700 and 800 are bundled under `assets/fonts/` (SIL Open Font License, `assets/fonts/LICENSE.txt`). The app respects the system font scale; only the fixed-height iOS tab bar caps its labels at 1.3×.

| Role | Size and weight |
| --- | --- |
| Screen title | iOS 34 / 800 large title; Android 24 / 600 top-bar title |
| Question title | 28 bold |
| Hero title, small metric | 22 bold |
| Card title, row title, nav title | 17 semibold |
| Button label | iOS 17 semibold, Android 16 semibold |
| Body | 17 regular |
| Row detail | 15 regular |
| Helper text | 13 regular |
| Unit caption (CAL, G) | 12 bold, uppercase, 0.8 tracking |
| Hero numeral (stepper) | 68 bold |
| Wordmark | "Nutri" in white and "Scan" in lime, one word, Inter 800, letter-spacing -0.03em |

**Shared components.** Each one has a golden test in `test/golden_test.dart` (dark, text scale 2.0).

| Component | Spec | Flutter |
| --- | --- | --- |
| MetricRing (EnergyRing) | Track plus a round-capped arc clockwise from 12 o'clock. Progress is clamped to 0-100%, so over target the ring stays full and the number beside it shows the real total. An ink arrow rides the cap once progress passes 2%, sized at 52% of the stroke. Hero ring is 132 dp with a 24 dp stroke and shows "N left" inside. Animates for 0.5 s unless reduced motion is on | `CustomPainter` in `rings.dart` |
| MiniRingGlyph | 30 dp with a 4 dp stroke, used on the week strip and calendar | Same painter |
| WeekStrip | Seven days with a mini ring each; today's letter and date in lime; selected day on a raised pill | `history_screen.dart`, shared with Summary |
| FitnessCard (AppCard) | Card colour, platform card radius, padding 16, optional title row with a 24 dp round chevron | `Material` plus `InkWell` |
| NutrientTile | Name, value in the nutrient colour with a unit caption, "of N g", and a 6 dp progress bar. With no target (fiber) it shows "Today" and no bar | `common.dart` |
| StreakChip | Raised pill with a flame and "N day streak" or "Start a streak" | `common.dart` |
| GroupedCard and CardRow | Settings lists with dividers; row title, detail, and a chevron, check mark or value | `Column` of rows |
| PrimaryButton | Lime pill, ink label, 52 dp high, 40% opacity when disabled, a spinner replaces the label while loading | Theme `FilledButton` |
| SecondaryButton | Raised pill with brandDeep label; frosted white on the auth screens | `FilledButton` style |
| AuthField (AppTextField) | iOS: label above a filled card-colour field, lime border on focus. Android: outlined, label on the border, 2 px lime on focus. Red outline and `#FF8C80` helper text on error | Theme `InputDecoration` |
| Navigation | iOS: translucent capsule, 64 high, 16 from the sides and 24 from the bottom, 10 px labels, active item lime. Android: Material 3 `NavigationBar`, 80 high, lime indicator pill with a black icon, 12 px labels, plus an extended "Scan meal" FAB on Summary | `FloatingTabBar` / `NavigationBar` in `router.dart` |
| Segmented control | iOS: grey capsule with a raised thumb. Android: outlined, lime when selected, with a check | `SegmentedButton`, styled in the theme |
| ScanBrackets | Four rounded corner brackets; faint behind the sign-in header, lime as the Scan viewfinder | `CustomPainter` |
| ConfidenceBadge | Tinted capsule: 0.75 or more green "High confidence"; 0.45 to below 0.75 yellow "Review suggested"; below 0.45 red "Low confidence — please correct"; none grey "Estimate" | Stateless widget |
| AllergenWarningBanner | Energy red at 22% fill, warning icon, title "Possible allergens", the list, then "AI estimate only — always verify if you have allergies." | Stateless widget |
| EstimateDisclaimer | "Nutrition values are AI estimates for personal tracking — not medical advice or diagnoses." | Shown on Summary, Scan, result and meal detail |
| OfflineBanner | Carbs-yellow bar, ink text "You're offline. Showing saved data." | Driven by `connectivity_plus` |
| States | Loading spinner with message; Empty with icon, title, message and optional lime action; Error with "Something went wrong", the message and "Try again" | Shared widgets used by every screen |
| MealRow | 48 dp thumbnail (radius 10, or lime tint with a fork-and-knife icon), name, "Lunch · 420 kcal", and "18g P" in the protein colour | Reused in Summary and History |
| CircleMemberRow | Initial, name, "Logged today" (green) / "Not yet" / "Streak hidden", flame and streak days. Never calories, weight or photos | `circles_screen.dart`, shared with Progress |

**Android adaptations.** Use Material 3 as the base theme with these tokens in a custom `ColorScheme`. Use ripples instead of iOS highlights, the system back gesture, and edge-to-edge drawing. The auth screens use a black canvas with soft red, purple and lime glows built from radial gradients.

**App icons.** Generated from `assets/brand/`: `logo-mark.png` (in-app, 512 px), Android legacy `ic_launcher.png` and the adaptive foreground (black mark on transparent) over a solid lime `ic_launcher_background`, and opaque iOS `AppIcon` PNGs from `app-icon-ios.svg`.

## 7. Navigation and screens

The app has four tabs (Summary, Scan, Progress, Profile) behind a sign-in gate and a one-time onboarding, exactly as `RootView` and `MainTabView` do on iOS. Routing uses `go_router` with a redirect that reads the session: signed out goes to Welcome, signed in without onboarding goes to Onboarding, otherwise to the tabs. Each tab keeps its own back stack. Android's back gesture works everywhere, and leaving the review screen with a scan or edits unsaved asks "Discard this meal?".

Copy below is taken from the iOS app unless marked **new**. Items marked **new** are additions this plan makes for real accounts, or fixes for gaps in iOS.

**Sign-in and onboarding**

| Screen | Contents, top to bottom | Behaviour and states |
| --- | --- | --- |
| Splash (new) | Wordmark on black | Reads secure storage, refreshes the token if needed, then routes. Never shows Welcome to a signed-in user |
| Welcome | Glow background, wordmark, "Snap your plate. Know what's in it.", "Photo-first nutrition tracking with editable estimates and private streaks.", three value rows (one photo becomes calories and macros; protein ideas that fit how you eat; share streaks only, never calories or weight), Sign in (lime), Create account (frosted) | Static |
| Sign in | Back; logo mark 72 dp over faint scan brackets; "Welcome back"; "Sign in to keep your streak going."; Email; Password; **Forgot password?** (new); Sign in (lime); an "or" divider on iOS; Join with an invite (frosted, opens Create account); footer "NutriScan is invite-only. Ask a friend to add your email." | Email must look valid and password must be non-empty; do not enforce the new 8-character rule here so older passwords still work. Server errors show under the fields in red. Button shows a spinner |
| Create account | Back, "Create your account.", "Two minutes now, then just point your camera at a plate.", Display name, Email, Password, Confirm password, Continue | Name 2+ characters, email valid, password 8+ (show/hide toggle), passwords match ("Passwords do not match."). Server errors: email already registered |
| Forgot password (new) | Email, "Send code" | Always replies "If that email has an account, we've sent a code." and moves to the next screen |
| Reset password (new) | Email, emailed code, new password, confirm | Code is valid for 1 hour and allows 5 attempts. Success signs out other sessions and returns to Sign in |
| Onboarding | Back button (from step 2), progress bar, Skip (step 1 only), title and subtitle, content, Next or Finish at bottom right | Step 1 "What are you working towards?" picks Fat loss, Muscle gain or Maintenance (required). Step 2 "How do you eat? Choose all that apply." lists the 9 restrictions. Step 3 "How hard do you want to push protein?" is a slider from Gentle to Ambitious showing "N g a day", where N = base × (0.85 + 0.35 × slider), rounded, and base is 150, 180 or 140 g for the three modes. Step 4 "Want a private accountability circle?" is Yes or Not now (required). Finish saves goals, diet and the sharing flag, then marks onboarding done. Skip marks it done with the Maintenance defaults (2200 kcal, 140 g protein, 220 g carbs, 70 g fat) |

**Summary and Scan**

| Screen | Contents, top to bottom | Behaviour and states |
| --- | --- | --- |
| Summary | Offline banner when offline; "Summary" with today's date and a lime avatar button to Profile; streak chip; week strip (mini ring per day, today in lime); Energy card with the ring showing "N left", "Eaten 1,240", "of 2,200 kcal" and a goal-mode chip; 2 × 2 nutrient tiles (Protein, Carbs, Fat with progress bars; Fiber with no target); Protein Navigator card; Meals card; disclaimer. Android adds an extended "Scan meal" FAB | Pull to refresh. The Energy card opens Goals; tiles, the week strip and the Meals card open History. Meals states: loading, error with retry, empty ("No meals recorded." and "Scan your first meal"), or rows that open Meal detail |
| Scan: start | "Scan", "Photo, estimate, confirm"; panel "Snap. Review. Log." and "Nothing is saved until you confirm the numbers."; Take photo (lime); Choose from gallery; "How it works" (3 steps); disclaimer; **Add a meal manually** (new) | Camera and gallery both go through `image_picker`. A photo is compressed before upload (section 9) |
| Scan: working | Centered spinner | "Uploading meal photo…" then "Analysing your meal…" with "Detecting foods and estimating nutrition." Cancel is allowed and drops the request |
| Scan: review | Photo (220 dp high); identity card with the confidence badge, editable meal name and "Edit anything that looks off — corrections are saved with the meal."; allergen banner if any; Meal 2 × 2 picker (Breakfast, Lunch, Dinner, Snack); Estimate card with kcal and four macro tiles (protein, carbs, fat, fiber); "Correct estimate" panel; "Detected items" with serving and kcal; disclaimer; bottom bar with "Confirm and log" and "Retake" | The correction panel (Calories, Protein, Carbs, Fat, Fiber) opens by itself at medium or low confidence. The meal type defaults by time of day (new; iOS always starts on Lunch). Saving is blocked while a save is in flight and a repeat sends the same id. On success show a snackbar "Meal logged" and switch to Summary (new; iOS shows an alert and stays on Scan) |
| Scan: error | Warning icon, "Something went wrong", the message, "Try again", **Add manually** (new) | Non-food shows the model's reason, or "We couldn't find food in this photo. Try a clearer meal photo, or add it manually." Quota reached shows when scans reset |
| Meal detail | Photo, name, "Lunch · Oct 27, 1:05 PM", kcal, protein, carbs and fat, fiber row, "You corrected this estimate" note when true, Items, disclaimer | **New:** overflow menu with Delete (confirm) and, at P1, Edit |
| Add meal | Food name, Type (default Snack), Calories (required, 0 or more), Protein, Carbs, Fat (optional, default 0), **Notes** (new), "Save meal" | Error "Enter a name and valid calorie amount." iOS has this screen but nothing links to it, so the Flutter app exposes it from Scan and from the Scan error state |
| Goals (sheet) | Close; "Your daily targets" and "Pick a goal mode for a starting point, then tune each target. These are personal tracking goals, not medical advice."; Energy, Protein, Carbs, Fat picker; a large stepper; "All targets" card; "Goal mode" list; "Save targets" | Ranges and steps are in section 3. Picking a mode replaces all four numbers and says "Applied Fat loss suggestions — adjust anything below." Suggested targets: Fat loss 1800 kcal, 150 g protein, 160 g carbs, 55 g fat; Muscle gain 2800, 180, 300, 80; Maintenance 2200, 140, 220, 70. Error: "Calories and protein must be greater than zero." |

**Progress**

| Screen | Contents, top to bottom | Behaviour and states |
| --- | --- | --- |
| Progress hub | "Progress", "How meals and training add up"; Week / Month toggle; Daily average card (bar chart of daily calories, dashed goal line, today in lime, empty days as grey stubs); Protein average and Days logged tiles; Accountability card (everyone in your circles, one row each) with "Circles share streaks only — never calories, weight, or body images."; Insights (Weekly charts, Meal history) | The Accountability card opens Circles; rows open the screens below. Workouts are not built yet |
| Weekly charts | Three bar charts for the last 7 days: Energy (red), Protein (purple), Workout frequency (lime) | Data comes from the daily-totals endpoint, not from downloading every meal |
| Meal history | Title is the chosen date; calendar and reload buttons; week strip with a mini ring per day; large ring (240 dp high, 38 dp stroke); Energy readout; calories-through-the-day chart in 12 two-hour buckets with a peak label and "Total N cal"; four macro stats; Meals card | Empty day shows "Nothing logged that day. Pick another day, or scan your next meal." The calendar sheet is a month grid with a mini ring per day |
| Circles | Create a circle (name, button); Join a circle (code, button); each circle with its members showing name, streak days and whether they logged today, sorted logged-today first then by streak | Up to 10 circles per person and 5 members per circle. Codes are 6 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no 0, 1, I or O). Errors: "Enter a valid invite code.", "No circle found for that invite code.", "This circle is full (max 5 members)." A member who turned streak sharing off shows by name with "Streak hidden" (new) |
| Workouts | This week (count) and Time (minutes) cards; "Log workout"; "Recent workouts" with an icon per type, title, "Strength · 45 min" and date; "N workouts this week · M this month" | Empty: "No workouts yet" and "Log a session to start your activity history." |
| Log workout (sheet) | Type (strength, running, walking, cycling, boxing, sports, other), Title, Duration in minutes (default 45), Distance in km for running, walking and cycling, strength fields (exercise, sets, reps, weight in kg), Notes, "Save workout" | Duration must be above 0 ("Enter a duration in minutes."). Title defaults to the type name |

**Profile**

| Screen | Contents, top to bottom | Behaviour and states |
| --- | --- | --- |
| Profile | "Profile" and @username; identity card (lime avatar initial, name, email, bio) opening Edit profile; Goals (Goal mode, Daily energy, Macros, each opening Goals); Dietary preferences as chips (selected lime, saved on tap) plus Dietary notes; Circles (Share my streak switch); Account (Edit profile, Privacy & data); Appearance segmented control (System, Light, Dark); disclaimer; Sign out; **Delete account** | "Dark is recommended. NutriScan is designed for it." under Appearance. Sign out shows "Signing out…". Delete account is red, asks for the password and a second confirmation. Change password and Sign out of all devices are not built yet (password reset goes through Neon Auth) |
| Edit profile | Avatar, Upload photo, Remove photo, Display name, Username, Bio, Save | Username is trimmed and lowercased; a taken name shows an error. Avatar is resized to 512 px |
| Dietary preferences | Nine restrictions with check marks (Vegetarian, Eggetarian, Vegan, Gluten-free, Dairy-free, Nut-free, Shellfish-free, Halal, Kosher), Notes, Save | Caption: "Used for next-meal ideas and allergen awareness. Not a medical allergy profile." |
| Privacy and data | Four toggles: Public profile; Share nutrition consistency; Share workouts; Streak sharing in circles. Caption on what circles share | All default off. Only the streak toggle has an effect in v1; the others are stored for the later community feature |
