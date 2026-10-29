# NutriScan: Screen and Brand Spec

Handoff for the Flutter build. Mockups: the "NutriScan App Design" canvas (logo, icons and 11 screens). Pack tokens: `nutriscan-flutter-cursor-pack/lib/core/theme/app_tokens.dart`; the app reads them from `lib/app/theme.dart`.

## Brand

- Mark: a scan frame (four corner brackets) around an energy ring with a centre dot. Lime `#C9FF3D` with black strokes, or lime strokes on `#1C1C1E`.
- Wordmark: "Nutri" in white and "Scan" in lime, Inter 800, letter-spacing -0.03em.
- Files in `assets/brand/`:

| File | Use |
| --- | --- |
| `logo-mark.svg` | In-app logo on sign-in and splash |
| `logo-mark-on-dark.svg` | Small mark on dark cards |
| `app-icon-ios.svg` | Export 1024 x 1024 PNG, no transparency, for the iOS icon |
| `app-icon-android-foreground.svg` | Export 432 x 432 PNG with transparency; Android adaptive foreground |
| `app-icon-android-background.svg` | Android adaptive background (solid lime) |

The launcher icons and `logo-mark.png` are already generated from these SVGs (see DESIGN.md, App icons).

## Tokens

| Token | Value |
| --- | --- |
| Brand lime | `#C9FF3D` (text on it: black) |
| Canvas / card / raised | `#000000` / `#1C1C1E` / `#2C2C2E` |
| Text primary / secondary | `#FFFFFF` / `#A1A1A6` |
| Energy / protein / carbs / fat / fiber | `#FA114F` / `#BF5AF2` / `#FFD60A` / `#64D2FF` / `#30D158` |
| Font | Inter 400, 600, 700, 800, bundled |
| Page padding | 16 (auth screens 24) |
| Card radius | iOS 22, Android 28 |

## Platform chrome

| Element | iOS | Android |
| --- | --- | --- |
| Navigation | Floating capsule, 64 high, 16 from the sides and 24 from the bottom, 10 px labels, active item lime | `NavigationBar`, 80 high, 64 x 32 lime indicator pill with black icon, 12 px labels |
| Page title | 34 / 800 large title | 24 / 600 top-bar title |
| Primary button | 52-54 high pill, 17 / 600 | 48-52 high pill, 16 / 600 |
| Text fields | Label above, filled `#1C1C1E`, radius 14, lime border on focus | Outlined, label on the border, radius 12, 2 px lime on focus |
| Scan entry | Scan tab | Scan tab plus extended FAB "Scan meal" on Summary |
| Segmented control | Grey capsule with raised thumb | Outlined Material segmented button with a check |

## Screens

### Sign in
Logo mark 72 px, "Welcome back", "Sign in to keep your streak going." Email and password fields, "Forgot password?", lime **Sign in**, a divider (iOS), and **Join with an invite**. Footer: "NutriScan is invite-only. Ask a friend to add your email." Faint scan-bracket shapes sit behind the header.
As built: access is gated by an email invite list on the server (`python -m app.admin allow add <email>`), not a code, so the copy says "add your email". Sign-up and forgot-password reuse the same pattern; password reset is an emailed Neon Auth link.

### Summary
Date and title, streak chip, seven-day week strip (ring per day, today in lime), energy ring card (1,240 of 2,200 kcal, "960 left"), 2 x 2 nutrient tiles with progress bars, Protein Navigator card, latest meal row (iOS).

### Scan result ("Review meal")
Photo area, meal name, confidence badge (High / Review suggested / Low confidence), item list with serving and kcal (tap to edit), four macro tiles, allergen banner, **Confirm and log**, and **Retake**. Nothing is saved until Confirm.

### Progress
Week / Month toggle, daily-average bar chart with a dashed goal line (today in lime, empty day as a small grey stub), protein average and days-logged tiles, accountability circle list (name, "Logged today" / "Not yet", streak days).

### Profile
Avatar initial, name, email. Goal rows (mode, daily energy, macros). Dietary preference chips (selected lime). Share-my-streak switch, appearance, **Sign out**.

## Widgets to build once

`EnergyRing`, `NutrientTile`, `WeekStrip`, `ConfidenceBadge`, `AllergenBanner`, `AppCard`, `PrimaryButton`, `AppTextField`, `StreakChip`, `PlatformNavBar`. Each has a golden test in `test/golden_test.dart` (dark mode, text scale 2.0).
