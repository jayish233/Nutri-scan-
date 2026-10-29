# NutriScan Flutter: Design

## 6. Design foundations

The Flutter app keeps the iOS look: a pure black canvas, lime for actions, five fixed metric colours, pill buttons and heavy rounded rings. Values below are copied from `Tokens.swift` and the shared components, so the two apps read as one product. The colours in the older Android `PRD.md` are out of date and should not be used.

**Colour**

| Token | Dark | Light | Used for |
| --- | --- | --- | --- |
| canvas | `#000000` | `#F2F2F7` | App background |
| card | `#1C1C1E` | `#FFFFFF` | Cards, tiles |
| cardElevated | `#2C2C2E` | `#E5E5EA` | Tab bar, pills, round buttons |
| primaryText | `#FFFFFF` | `#000000` | Main text |
| secondaryText | `#8E8E93` | `#6B6B70` | Captions, helper text |
| hairline | white at 10% | black at 10% | Dividers, borders |
| brand (lime) | `#C9FF3D` | `#C9FF3D` | Primary buttons, active tab, highlights |
| brandDeep | `#C9FF3D` | `#446600` | Lime text on a light surface |
| ink | `#0B0B0C` | `#0B0B0C` | Text and icons sitting on lime |
| energy (calories) | `#FA114F` | same | Hero ring, kcal values |
| protein | `#BF5AF2` | same | Protein values and tiles |
| carbs | `#FFD60A` | same | Carb values, offline banner |
| fat | `#0AC8FF` | same | Fat values and tiles |
| fiber, success | `#4DE28C` | same | Fiber values, confirmations |

A ring or bar track is its metric colour at 22% opacity. A metric colour is never swapped for the brand colour. Dark is the default theme; Profile also offers Light and System. Sign-in and onboarding are always dark.

**Spacing and shape**

| Token | Value |
| --- | --- |
| Spacing | 4, 8, 12, 16, 24, 32, 48 |
| Corner radius | 10 small, 14 chip, 16 medium, 18 card, 22 large, full pill for buttons and the tab bar |
| Touch target | 48 dp minimum (iOS uses 44 pt) |
| Scroll bottom inset | 108 dp so the floating tab bar never covers the last row |

**Type.** iOS uses SF Pro. On Android use Inter, bundled in the app, which has similar proportions. Sizes follow the iOS text styles at default size, and the app must respect the system font scale.

| Role | Size and weight |
| --- | --- |
| Screen title, large metric | 34 bold |
| Question title | 28 bold |
| Hero title, small metric | 22 bold |
| Card title, row title, nav title | 17 semibold |
| Button label | 17 semibold |
| Body | 17 regular |
| Row detail | 15 regular |
| Helper text | 13 regular |
| Unit caption (CAL, G) | 12 bold, uppercase, 0.8 tracking |
| Hero numeral (stepper) | 68 bold |
| Wordmark | "nutri" regular and "Scan" bold, one word, white on black |

**Components to build first**

| Component | Spec | Flutter approach |
| --- | --- | --- |
| MetricRing | Track plus a round-capped arc clockwise from 12 o'clock. Progress is clamped to 0-100%, so over target the ring stays full and the number beside it shows the real total. An ink arrow rides the cap once progress passes 2%, sized at 52% of the stroke. Hero ring is 132 dp with a 24 dp stroke. Animates for 0.5 s unless reduced motion is on | `CustomPainter` |
| MiniRingGlyph | 30 dp with a 4 dp stroke, used on the week strip and calendar | Same painter |
| RingBadge | Three concentric tracks (energy, protein, fat), 64 dp, decorative, on the Consistency card | Same painter |
| FitnessCard | Card colour, radius 18, padding 16, optional title row with a 24 dp round chevron inside a 48 dp target | `Container` plus `InkWell` |
| MetricTile | Two per row: title, "Today", value in the metric colour with a unit caption, and a 58 dp bar chart of 12 two-hour buckets labelled 12 AM, 6 AM, 12 PM, 6 PM | `fl_chart` bar chart |
| GroupedCard and CardRow | Settings lists with dividers; row title, detail, and a chevron, check mark or value | `Column` of rows |
| PrimaryButton | Lime pill, ink 17 semibold label, 18 dp vertical padding, 35-40% opacity when disabled, a spinner replaces the label while loading | Custom `FilledButton` style |
| SecondaryButton | Elevated-surface pill with brandDeep label | `FilledButton.tonal` style |
| Auth text field | Frosted pill, white text, lime cursor, red outline plus helper text `#FF8C80` on error | `TextField` with custom decoration |
| Floating tab bar | Translucent capsule with hairline border and shadow; four items with a 19 dp icon and 10 semibold label; active item uses brandDeep | Custom widget in a `Stack`, not `NavigationBar` |
| ConfidenceBadge | Tinted capsule: 0.75 or more green "High confidence"; 0.45 to below 0.75 yellow "Review suggested"; below 0.45 red "Low confidence — please correct"; none grey "Estimate" | Stateless widget |
| AllergenWarningBanner | Energy red at 22% fill, warning icon, title "Possible allergens", the list, then "AI estimate only — always verify if you have allergies." | Stateless widget |
| EstimateDisclaimer | "Nutrition values are AI estimates for personal tracking — not medical advice or diagnoses." | Shown on Summary, Scan, result and meal detail |
| OfflineBanner | Carbs-yellow bar, ink text "You're offline. Showing saved data." | Driven by `connectivity_plus` |
| States | Loading spinner with message; Empty with icon, title, message and optional lime action; Error with "Something went wrong", the message and "Try again" | Shared widgets used by every screen |
| MealRow | 48 dp thumbnail (radius 10, or lime tint with a fork-and-knife icon), name, "Lunch · 420 kcal", and "18g P" in the protein colour | Reused in Summary and History |

**Android adaptations.** Use Material 3 as the base theme with these tokens in a custom `ColorScheme`. Use ripples instead of iOS highlights, the system back gesture, and edge-to-edge drawing. The auth screens use a black background with soft red, purple and lime glows; build them with blurred circles or radial gradients.

## 7. Navigation and screens

The app has four tabs (Summary, Scan, Progress, Profile) behind a sign-in gate and a one-time onboarding, exactly as `RootView` and `MainTabView` do on iOS. Routing uses `go_router` with a redirect that reads the session: signed out goes to Welcome, signed in without onboarding goes to Onboarding, otherwise to the tabs. Each tab keeps its own back stack. Android's back gesture works everywhere, and leaving the review screen with a scan or edits unsaved asks "Discard this meal?".

Copy below is taken from the iOS app unless marked **new**. Items marked **new** are additions this plan makes for real accounts, or fixes for gaps in iOS.

**Sign-in and onboarding**

| Screen | Contents, top to bottom | Behaviour and states |
| --- | --- | --- |
| Splash (new) | Wordmark on black | Reads secure storage, refreshes the token if needed, then routes. Never shows Welcome to a signed-in user |
| Welcome | Glow background, wordmark, "Snap your plate. Know what's in it.", "Photo-first nutrition tracking with editable estimates and private streaks.", three value rows (one photo becomes calories and macros; protein ideas that fit how you eat; share streaks only, never calories or weight), Sign in (lime), Create account (frosted) | Static |
| Sign in | Close, "Welcome back.", "Pick up your streak where you left it.", Email, Password, Continue, **Forgot password?** (new), Create account | Email must look valid and password must be non-empty; do not enforce the new 8-character rule here so older passwords still work. Server errors show under the fields in red. Button shows a spinner |
| Create account | Back, "Create your account.", "Two minutes now, then just point your camera at a plate.", Display name, Email, Password, Confirm password, **Invite code** (new, auto-uppercased), Continue | Name 2+ characters, email valid, password 8+ (show/hide toggle), passwords match ("Passwords do not match."). Server errors: code invalid, used or expired; email already registered |
| Forgot password (new) | Email, "Send code" | Always replies "If that email has an account, we've sent a code." and moves to the next screen |
| Reset password (new) | Email, emailed code, new password, confirm | Code is valid for 1 hour and allows 5 attempts. Success signs out other sessions and returns to Sign in |
| Onboarding | Back button (from step 2), progress bar, Skip (step 1 only), title and subtitle, content, Next or Finish at bottom right | Step 1 "What are you working towards?" picks Fat loss, Muscle gain or Maintenance (required). Step 2 "How do you eat? Choose all that apply." lists the 9 restrictions. Step 3 "How hard do you want to push protein?" is a slider from Gentle to Ambitious showing "N g a day", where N = base × (0.85 + 0.35 × slider), rounded, and base is 150, 180 or 140 g for the three modes. Step 4 "Want a private accountability circle?" is Yes or Not now (required). Finish saves goals, diet and the sharing flag, then marks onboarding done. Skip marks it done with the Maintenance defaults (2200 kcal, 140 g protein, 220 g carbs, 70 g fat) |

**Summary and Scan**

| Screen | Contents, top to bottom | Behaviour and states |
| --- | --- | --- |
| Summary | Offline banner when offline; "Summary" with today's date and an avatar button to Profile; Energy Ring card with the ring, "Eaten 760/2200 CAL", "N left today" and a goal-mode chip; four tiles (Protein, Carbs, Fat, Fiber); Scan card ("Scan a meal", "Photo, estimate, confirm"); Protein Navigator card; Meals card; Consistency card; disclaimer | Pull to refresh. The ring card opens Goals; tiles and the Meals card open History. Meals states: loading, error with retry, empty ("No meals recorded." and "Scan your first meal"), or rows that open Meal detail. Consistency shows "Start a streak" or "N day streak", plus "Workout logged today" or "N meals logged today", and "Circles only ever see this number." |
| Scan: start | "Scan", "Photo, estimate, confirm"; panel "Snap. Review. Log." and "Nothing is saved until you confirm the numbers."; Take photo (lime); Choose from gallery; "How it works" (3 steps); disclaimer; **Add a meal manually** (new) | Camera and gallery both go through `image_picker`. A photo is compressed before upload (section 9) |
| Scan: working | Centered spinner | "Uploading meal photo…" then "Analysing your meal…" with "Detecting foods and estimating nutrition." Cancel is allowed and drops the request |
| Scan: review | Photo (220 dp high); identity card with the confidence badge, editable meal name and "Edit anything that looks off — corrections are saved with the meal."; allergen banner if any; Meal 2 × 2 picker (Breakfast, Lunch, Dinner, Snack); Estimate card with kcal, protein, carbs, fat and fiber; "Correct estimate" panel; "Detected items" when there is more than one; disclaimer; bottom bar with "Confirm & save" and "Retake photo" | The correction panel (Calories, Protein, Carbs, Fat, Fiber) opens by itself at medium or low confidence. The meal type defaults by time of day (new; iOS always starts on Lunch). Saving is blocked while a save is in flight and a repeat sends the same id. On success show a snackbar "Meal logged" and switch to Summary (new; iOS shows an alert and stays on Scan) |
| Scan: error | Warning icon, "Something went wrong", the message, "Try again", **Add manually** (new) | Non-food shows the model's reason, or "We couldn't find food in this photo. Try a clearer meal photo, or add it manually." Quota reached shows when scans reset |
| Meal detail | Photo, name, "Lunch · Oct 27, 1:05 PM", kcal, protein, carbs and fat, fiber row, "You corrected this estimate" note when true, Items, disclaimer | **New:** overflow menu with Delete (confirm) and, at P1, Edit |
| Add meal | Food name, Type (default Snack), Calories (required, 0 or more), Protein, Carbs, Fat (optional, default 0), **Notes** (new), "Save meal" | Error "Enter a name and valid calorie amount." iOS has this screen but nothing links to it, so the Flutter app exposes it from Scan and from the Scan error state |
| Goals (sheet) | Close; "Your daily targets" and "Pick a goal mode for a starting point, then tune each target. These are personal tracking goals, not medical advice."; Energy, Protein, Carbs, Fat picker; a large stepper; "All targets" card; "Goal mode" list; "Save targets" | Ranges and steps are in section 3. Picking a mode replaces all four numbers and says "Applied Fat loss suggestions — adjust anything below." Suggested targets: Fat loss 1800 kcal, 150 g protein, 160 g carbs, 55 g fat; Muscle gain 2800, 180, 300, 80; Maintenance 2200, 140, 220, 70. Error: "Calories and protein must be greater than zero." |

**Progress**

| Screen | Contents, top to bottom | Behaviour and states |
| --- | --- | --- |
| Progress hub | "Progress", "How meals and training add up"; Insights (Weekly charts, Meal history); Accountability (Circles) with "Circles share streaks only — never calories, weight, or body images."; Fitness foundation (Workouts) with "Health Connect sync is planned for a later release." | Rows open the screens below |
| Weekly charts | Three bar charts for the last 7 days: Energy (red), Protein (purple), Workout frequency (lime) | Data comes from the daily-totals endpoint, not from downloading every meal |
| Meal history | Title is the chosen date; calendar and reload buttons; week strip with a mini ring per day; large ring (240 dp high, 38 dp stroke); Energy readout; calories-through-the-day chart in 12 two-hour buckets with a peak label and "Total N cal"; four macro stats; Meals card | Empty day shows "Nothing logged that day. Pick another day, or scan your next meal." The calendar sheet is a month grid with a mini ring per day |
| Circles | Create a circle (name, button); Join a circle (code, button); each circle with its members showing name, streak days and whether they logged today, sorted logged-today first then by streak | Up to 10 circles per person and 5 members per circle. Codes are 6 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no 0, 1, I or O). Errors: "Enter a valid invite code.", "No circle found for that invite code.", "This circle is full (max 5 members)." A member who turned streak sharing off shows by name with "Streak hidden" (new) |
| Workouts | This week (count) and Time (minutes) cards; "Log workout"; "Recent workouts" with an icon per type, title, "Strength · 45 min" and date; "N workouts this week · M this month" | Empty: "No workouts yet" and "Log a session to start your activity history." |
| Log workout (sheet) | Type (strength, running, walking, cycling, boxing, sports, other), Title, Duration in minutes (default 45), Distance in km for running, walking and cycling, strength fields (exercise, sets, reps, weight in kg), Notes, "Save workout" | Duration must be above 0 ("Enter a duration in minutes."). Title defaults to the type name |

**Profile**

| Screen | Contents, top to bottom | Behaviour and states |
| --- | --- | --- |
| Profile | "Profile" and @username; identity card (avatar, name, @username, bio); Nutrition (Daily goals, Dietary preferences); Account (Edit profile, Privacy & data, **Change password**, **Sign out of all devices**); Appearance (System, Light, Dark); disclaimer; Sign out; **Delete account** | Appearance rows read "Follows your phone setting.", "Always use the light theme." and "Recommended. NutriScan is designed for dark." Sign out shows "Signing out…". Delete account is red, asks for the password and a second confirmation |
| Edit profile | Avatar, Upload photo, Remove photo, Display name, Username, Bio, Save | Username is trimmed and lowercased; a taken name shows an error. Avatar is resized to 512 px |
| Dietary preferences | Nine restrictions with check marks (Vegetarian, Eggetarian, Vegan, Gluten-free, Dairy-free, Nut-free, Shellfish-free, Halal, Kosher), Notes, Save | Caption: "Used for next-meal ideas and allergen awareness. Not a medical allergy profile." |
| Privacy and data | Four toggles: Public profile; Share nutrition consistency; Share workouts; Streak sharing in circles. Caption on what circles share | All default off. Only the streak toggle has an effect in v1; the others are stored for the later community feature |
