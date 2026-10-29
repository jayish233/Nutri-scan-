# NutriScan iOS Frontend PRD + Cursor Build Prompt

## 1. Project Overview

Build a production-quality native iOS application named **NutriScan**.

NutriScan is a nutrition and fitness companion that lets users:

- Take a photo of food and have the backend AI recognise the meal.
- Receive estimated calories, protein, carbohydrates, fats, serving/portion information, and other nutrition data returned by the backend.
- Save analysed meals into a daily food log.
- Track daily calorie and macronutrient progress.
- Set and monitor daily protein and nutrition goals.
- Log and track workouts.
- View fitness and nutrition progress over time.
- See a social/community feed where users can share their fitness journey and compare healthy consistency/progress metrics with other users.

IMPORTANT:
The backend is already implemented. Do NOT rebuild the backend.
The iOS app is the frontend/client only.

The backend repository should be available locally through:

    git clone https://github.com/Nutriscan-io/nutriscan.git

Before implementing networking, inspect the cloned backend and determine:

1. Backend framework and project structure.
2. API base URL/configuration.
3. Authentication flow.
4. All available API routes/endpoints.
5. Request parameters/body formats.
6. Response JSON structures.
7. Authentication headers/token format.
8. Image upload requirements and multipart/form-data field names.
9. Food analysis response schema.
10. User/profile endpoints.
11. Nutrition/meal history endpoints.
12. Goal endpoints.
13. Workout/activity endpoints.
14. Social/community endpoints.
15. Error formats and HTTP status behaviour.
16. Any pagination, sorting, filtering, or refresh-token mechanisms.

DO NOT invent backend endpoints when an equivalent endpoint exists.
Create a typed API client based on the actual backend contract.

If an endpoint required by this PRD does not exist in the backend, isolate that capability behind a clearly marked service/protocol and provide a compile-safe mock implementation for development rather than changing the backend.

---

# 2. Primary Product Goal

Make calorie and nutrition tracking extremely low-friction.

The core experience should be:

    Open app
      -> Tap "Scan Food"
      -> Take/select food photo
      -> Upload to backend
      -> Show analysis/loading state
      -> Display recognised food + nutrition
      -> User reviews/edits serving if supported
      -> Save meal
      -> Dashboard updates immediately

The app should feel fast, modern, polished, minimal, and native to iOS.

The visual direction should take inspiration from premium Apple-style health/productivity apps:

- Clean typography
- Large readable numbers
- Strong spacing
- Rounded cards
- Subtle depth
- Smooth animations
- Minimal clutter
- Excellent dark mode
- Native iOS navigation
- Accessible controls
- No unnecessary gradients or visual noise

Do not copy Apple's UI. Create an original NutriScan visual identity.

---

# 3. Target Platform

Build for modern iOS using:

- Swift
- SwiftUI
- Swift Concurrency / async-await
- URLSession
- Codable
- PhotosUI
- AVFoundation where camera access is needed
- Swift Charts where appropriate
- Keychain for sensitive authentication tokens
- UserDefaults/AppStorage only for non-sensitive local preferences

Prefer Apple frameworks over unnecessary third-party libraries.

Minimum target:

- iOS 17+

The project should compile cleanly in Xcode.

---

# 4. Recommended Architecture

Use a clean, maintainable architecture.

Suggested structure:

    NutriScan/
    ├── App/
    ├── Core/
    │   ├── Networking/
    │   ├── Storage/
    │   ├── Extensions/
    │   ├── Components/
    │   └── DesignSystem/
    ├── Models/
    ├── Services/
    │   ├── Auth/
    │   ├── Nutrition/
    │   ├── FoodAnalysis/
    │   ├── Goals/
    │   ├── Workouts/
    │   └── Social/
    ├── Features/
    │   ├── Authentication/
    │   ├── Dashboard/
    │   ├── FoodScanner/
    │   ├── MealDetails/
    │   ├── Nutrition/
    │   ├── Workouts/
    │   ├── Progress/
    │   ├── Community/
    │   └── Profile/
    └── Resources/

Use:

- MVVM for feature presentation.
- Protocol-oriented services for testability.
- Dependency injection for networking and data services.
- Typed request/response models.
- MainActor for UI state.
- async/await instead of completion-handler networking.

Avoid putting API calls directly inside Views.

---

# 5. Authentication

Implement authentication according to the actual backend.

Expected possibilities may include:

- Email/password login
- Registration
- Logout
- Token persistence
- Token refresh
- Current-user/profile retrieval

The frontend must adapt to the actual backend contract after inspecting it.

Required screens:

### Welcome / Landing

Show:

- NutriScan logo/name
- Short value proposition
- Sign in
- Create account

### Login

Fields:

- Email
- Password

Actions:

- Sign in
- Forgot password, only if supported by backend
- Create account

### Registration

Fields based on backend requirements.

### Auth handling

Implement:

- Loading state
- Inline validation
- API errors
- Invalid credentials state
- Session restoration
- Logout

Never store passwords locally.

Store access/refresh tokens securely in Keychain when applicable.

---

# 6. Main App Navigation

Use a tab-based layout.

Suggested tabs:

1. Home
2. Scan
3. Activity
4. Community
5. Profile

The central Scan action should be visually prominent.

Use a native-looking TabView or a custom SwiftUI tab bar only where it genuinely improves UX.

---

# 7. Home Dashboard

The home screen is the primary daily overview.

Display:

### Daily Nutrition Summary

- Calories consumed
- Remaining calories when a target exists
- Protein consumed / target
- Carbohydrates consumed / target
- Fat consumed / target

Use a visually clear calorie ring/progress indicator.

Example:

    1,480 kcal
    of 2,200 kcal

Do not make health claims based purely on calorie totals.

### Meal Timeline

Show:

- Breakfast
- Lunch
- Dinner
- Snacks

Each item can display:

- Food image
- Meal name
- Calories
- Protein
- Time

Tapping opens detailed meal information.

### Quick Actions

- Scan food
- Add meal manually
- Log workout
- Set/edit goals

### Daily consistency

Show positive, non-judgmental metrics such as:

- Meals logged
- Workout completed
- Protein goal progress
- Logging streak

Avoid shame-based messaging.

---

# 8. Food Scanner

This is the most important feature.

## Entry screen

Provide two actions:

- Take Photo
- Choose from Photos

Request permissions only when needed.

### Camera UI

Create a polished native camera experience:

- Large preview
- Capture button
- Gallery button
- Cancel button
- Clear instructional text

Keep the camera screen simple.

### Image preparation

Before sending:

- Validate an image exists.
- Resize/compress only as necessary.
- Preserve enough detail for food recognition.
- Show upload/analyse progress.
- Handle poor network conditions gracefully.

Never expose backend API secrets in the app.

---

# 9. Food Analysis Flow

After image submission:

### State 1: Uploading

Show:

    Uploading meal photo...

### State 2: Analysing

Show an engaging but simple loading state:

    Analysing your meal...

Use subtle animation.

### State 3: Results

Display:

- Recognised food name
- Confidence score only if returned by backend
- Estimated serving/portion
- Calories
- Protein
- Carbohydrates
- Fat
- Other nutrients returned by the backend
- Ingredients if returned
- Image

If the backend returns multiple foods in one photo, display each item separately plus a total.

Example:

    Chicken Rice Bowl

    Chicken       320 kcal
    Rice           280 kcal
    Vegetables      90 kcal
    Sauce           70 kcal
    ----------------------
    Total          760 kcal

Do NOT fabricate values when the backend does not return them.

---

# 10. Meal Confirmation

Before saving, allow the user to review the result.

Possible editable fields:

- Meal type
- Food name
- Portion/serving, only if supported
- Quantity, only if supported

Actions:

- Save meal
- Retake photo
- Edit

After saving:

- Update dashboard immediately.
- Add meal to history.
- Show success feedback.

Avoid duplicate saving if the user taps the Save button repeatedly.

---

# 11. Manual Meal Logging

Provide a fallback for users who do not want to scan.

Allow:

- Food name
- Meal type
- Calories
- Protein
- Carbs
- Fat
- Quantity/serving where applicable

Prefer backend-supported food search if available.

If food search does not exist in backend, implement the UI in a modular way and clearly mark the missing service.

---

# 12. Nutrition History

Create a dedicated nutrition screen.

Show:

- Meals by day
- Daily calories
- Daily protein
- Daily carbohydrates
- Daily fat
- Weekly summaries
- Monthly trends where backend data supports it

Use Swift Charts for:

- Calories over time
- Protein over time
- Macronutrient trends
- Workout frequency

Keep charts readable on small iPhone screens.

Add filters:

- Today
- Week
- Month

Only expose filters that can be supported by the backend or locally cached history.

---

# 13. Daily Nutrition Goals

Users should be able to set personal tracking goals.

Initial focus:

- Daily calorie target
- Daily protein target
- Optional carb target
- Optional fat target

Do not hard-code medical or nutritional prescriptions.

Goals should be user-defined or backend-provided.

Goal screen:

    Daily Goals

    Calories
    [ 2200 ] kcal

    Protein
    [ 120 ] g

    Carbohydrates
    [ optional ]

    Fat
    [ optional ]

    Save Goals

If backend provides calculated goals, present those as backend values and make it clear they are estimates where applicable.

---

# 14. Workout Tracking

Create a dedicated Activity/Workout section.

Users should be able to:

- Start/log a workout
- Select workout type
- Record duration
- Record exercises
- Record sets/reps/weight when relevant
- Add notes
- Save workout

Suggested workout types:

- Strength
- Running
- Walking
- Cycling
- Boxing
- Sports
- Other

Do not require every field for every workout type.

For example:

Strength:
- Exercise
- Sets
- Reps
- Weight

Cardio:
- Activity
- Duration
- Distance when available

Show workout history:

    Monday
    Strength
    48 min

    Tuesday
    Running
    32 min

Avoid turning the app into a competition based solely on body size or appearance.

---

# 15. Activity Dashboard

Show:

- Weekly workout count
- Total workout time
- Current consistency
- Recent workouts
- Workout calendar
- Optional workout trends

Use encouraging, factual language.

Examples:

- "3 workouts this week"
- "You've logged 12 sessions this month"
- "Protein goal reached 5 of the last 7 days"

Avoid:

- "You are better than 90% of people because of your body."
- Appearance-based rankings.
- Shame for missed days.

---

# 16. Community / Social Fitness Journey

Users should be able to see how others are progressing in a healthy, non-toxic way.

Community features:

- Public profile
- Display name
- Profile photo/avatar
- Bio
- Journey posts
- Workout posts
- Nutrition consistency posts
- Progress milestones
- Likes/reactions if backend supports them
- Comments if backend supports them
- Follow/unfollow if backend supports them

## Community Feed

Example cards:

    Alex
    "Completed 4 workouts this week"

    4 workouts
    3 nutrition goals completed

Or:

    Sarah
    "Started my 30-day consistency challenge"

The social layer should focus on consistency, habits, workouts logged, meals logged, and personal milestones rather than ranking bodies, weight, attractiveness, or other appearance-based traits.

### Compare feature

Allow comparison of neutral fitness-journal metrics when supported:

- Workouts completed
- Weekly activity consistency
- Nutrition logging consistency
- Streaks
- Personal milestones

Do not create public leaderboards for weight loss or body appearance.

---

# 17. Profile

Profile should show:

- Name
- Username
- Avatar
- Bio
- Goal summary
- Workout stats
- Nutrition stats
- Journey milestones

Actions:

- Edit profile
- Goals
- Notifications
- Privacy
- Sign out

Provide a clear privacy model for social sharing.

---

# 18. Privacy Controls

Users should control what is public.

Settings:

- Profile visibility
- Journey post visibility
- Nutrition visibility
- Workout visibility

Nutrition data should be private by default unless the backend explicitly supports a sharing choice.

Do not expose sensitive health-style information publicly without explicit user action.

---

# 19. State Management

Each feature must have explicit UI states:

- Idle
- Loading
- Success
- Empty
- Error

Example:

    enum ViewState {
        case idle
        case loading
        case loaded
        case empty
        case error(message: String)
    }

Do not leave users staring at blank screens.

---

# 20. Networking Layer

Build a reusable API client.

Example conceptual interface:

    protocol APIClient {
        func request<T: Decodable>(
            _ endpoint: Endpoint
        ) async throws -> T

        func upload<T: Decodable>(
            _ endpoint: Endpoint,
            imageData: Data,
            fieldName: String
        ) async throws -> T
    }

The exact implementation must match the backend after inspection.

Support:

- GET
- POST
- PUT/PATCH
- DELETE
- Multipart image upload
- Authenticated requests
- Token refresh if backend supports it
- JSON decoding
- Server error decoding
- Timeout handling
- Network unavailable handling

Centralise:

- Base URL
- Headers
- Authorization
- Request building
- Response validation
- Error parsing

Do not scatter URL strings across Views.

---

# 21. Backend Contract Discovery Requirement

At the start of implementation, Cursor must inspect the backend repository and produce an internal mapping such as:

    EndpointMap.md

Containing:

    Feature
    Endpoint
    Method
    Request
    Response
    Auth required
    Notes

Do not make up these values.

Example format:

    Food Analysis
    POST /<actual-route>
    multipart/form-data
    image=<actual-field>
    response=<actual-schema>

Then implement the Swift API models from that mapping.

If the backend has OpenAPI/Swagger documentation, use it as the primary contract.

If the backend has tests that define endpoint behaviour, use those as a secondary source.

---

# 22. Error Handling

Create typed client errors:

- invalidURL
- unauthorized
- forbidden
- notFound
- validation
- server
- decoding
- network
- cancelled
- unknown

Convert backend errors into user-friendly messages.

Do not display raw JSON or stack traces to users.

Example:

Backend:
    {"detail":"Token expired"}

UI:
    "Your session has expired. Please sign in again."

---

# 23. Offline and Resilience

The app should fail gracefully when offline.

At minimum:

- Preserve cached dashboard data.
- Preserve locally selected photos until upload is complete.
- Show an offline banner/state.
- Allow viewing previously loaded history.

Do not pretend that a meal was saved if the server did not confirm the save.

A small persistence layer can be implemented with SwiftData only where useful.

Do not create a complicated offline-sync engine unless the backend requires it.

---

# 24. Image Handling

Use:

- PhotosPicker for photo library selection.
- AVFoundation for camera.
- Async image loading where remote image URLs exist.

Create reusable:

    AsyncRemoteImage
    FoodImagePreview
    CameraCaptureView

Image upload must:

- Use correct multipart field from backend.
- Set correct MIME type.
- Handle large images.
- Display clear upload state.

---

# 25. Design System

Create a central design system.

Define reusable values for:

- Typography
- Corner radii
- Spacing
- Icons
- Buttons
- Cards
- Progress indicators
- Input fields
- Sheets
- Empty states
- Error states

Use system fonts initially.

Create reusable components:

    PrimaryButton
    SecondaryButton
    StatCard
    NutritionCard
    MacroProgressCard
    MealRow
    WorkoutRow
    ProgressRing
    SectionHeader
    EmptyStateView
    ErrorStateView
    LoadingView
    AvatarView

---

# 26. Accessibility

Support:

- Dynamic Type
- VoiceOver labels
- Sufficient contrast
- Large tap targets
- Reduce Motion
- Clear semantic accessibility values for charts/progress rings

Do not communicate essential information using colour alone.

---

# 27. Animations

Use animation deliberately.

Good uses:

- Scan result appearing
- Nutrition progress updating
- Tab transitions where appropriate
- Saving a meal
- Workout completion

Avoid excessive animation.

Animations should respect Reduce Motion.

---

# 28. Notifications

Only implement notifications supported by the backend/product scope.

Potential reminders:

- Meal logging reminder
- Workout reminder
- Daily goal check-in

Notifications must be optional and user-controlled.

Do not use guilt-based language.

---

# 29. Security

Never hard-code:

- API secrets
- Backend private keys
- AI provider keys
- Database credentials

Use Keychain for authentication credentials/tokens.

Use HTTPS for production.

Avoid logging access tokens or sensitive user data.

Remove debug logging from release builds.

---

# 30. Environment Configuration

Create environment-aware configuration:

    Development
    Staging
    Production

Example:

    API_BASE_URL

Do not hard-code localhost into production.

Keep environment configuration separate from feature code.

---

# 31. Loading, Empty, and Error UX

Every screen that loads remote data must have:

### Loading

Skeletons or polished progress indicators.

### Empty

Example:

    No meals logged today.
    Scan your first meal to get started.

### Error

Example:

    Couldn't load your nutrition data.
    Try again.

    [Retry]

Never show an empty screen with no explanation.

---

# 32. Performance

Requirements:

- Use async/await.
- Avoid unnecessary View recomputation.
- Lazy load long lists.
- Downsample images before uploading where appropriate.
- Cache remote images where practical.
- Avoid blocking the main thread.
- Keep scrolling smooth.

---

# 33. Testing

Create tests for:

### Networking

- Successful API request
- Unauthorized response
- Validation error
- Malformed JSON
- Network failure

### Food analysis

- Single food result
- Multiple food result
- Missing optional fields
- Backend error

### Goals

- Loading goals
- Saving goals
- Validation

### Workouts

- Create workout
- Load history
- Empty history

### UI

At minimum create tests for:

- Login flow
- Dashboard rendering
- Food analysis result rendering
- Meal saving
- Goal editing

Use mock services instead of real backend calls in unit tests.

---

# 34. Mock Development Mode

Create a mock API layer that mirrors the same protocols as the real API.

This lets the UI be developed when the backend is offline.

Mock data should be clearly marked as development-only.

Example mock food:

    Grilled Chicken Rice Bowl

    680 kcal
    Protein 42 g
    Carbs 72 g
    Fat 18 g

Do not allow mock mode to accidentally ship as production behaviour.

---

# 35. Suggested Screen Map

    Authentication
      ├── Welcome
      ├── Login
      └── Register

    Main App
      ├── Home
      │   ├── Daily Summary
      │   ├── Meals
      │   └── Quick Actions
      │
      ├── Scan
      │   ├── Camera
      │   ├── Photo Picker
      │   ├── Analysing
      │   └── Food Result
      │
      ├── Activity
      │   ├── Workout Dashboard
      │   ├── Log Workout
      │   └── Workout History
      │
      ├── Community
      │   ├── Feed
      │   ├── Post
      │   └── User Profile
      │
      └── Profile
          ├── Profile
          ├── Goals
          ├── Privacy
          ├── Settings
          └── Logout

---

# 36. Home Screen UX Priority

The order on the home screen should generally be:

1. Greeting/date
2. Calories + nutrition progress
3. Protein progress
4. Today's meals
5. Workout status
6. Quick scan button
7. Recent consistency/progress

The "Scan Food" action should always be easy to reach.

---

# 37. Data Models

Create typed Swift models based on the ACTUAL backend responses.

Potential conceptual models include:

    User
    UserProfile
    AuthResponse
    FoodAnalysis
    FoodItem
    NutritionInfo
    Meal
    MealSummary
    DailyNutrition
    NutritionGoal
    Workout
    Exercise
    WorkoutSummary
    ProgressSummary
    CommunityPost
    CommunityUser
    Comment
    Reaction

Do not add fields that the backend does not provide unless they are local-only UI state.

Use custom CodingKeys when backend naming differs from Swift naming.

---

# 38. Product Principles

The frontend must follow these principles:

### 1. Camera-first nutrition tracking

Photo analysis is the signature interaction.

### 2. Fast logging

A meal should be loggable in very few steps.

### 3. Trustworthy information

Do not invent nutrition values.

### 4. User control

Users can review the AI result before saving.

### 5. Healthy social experience

Community features should motivate consistency rather than appearance comparison.

### 6. Native iOS feel

Use SwiftUI and Apple platform conventions.

### 7. Backend-driven truth

The API contract is the source of truth.

---

# 39. Cursor Execution Instructions

You are acting as a senior iOS engineer.

Do NOT attempt to implement the entire project blindly in one giant file.

Work feature-by-feature.

FIRST:

1. Inspect the entire backend repository.
2. Identify the backend framework.
3. Identify API endpoints.
4. Identify authentication.
5. Identify request/response schemas.
6. Identify image upload flow.
7. Identify available nutrition endpoints.
8. Identify available goal endpoints.
9. Identify workout endpoints.
10. Identify community endpoints.
11. Produce an endpoint mapping document.
12. Identify any frontend-required capability missing from the backend.

SECOND:

Create the Xcode SwiftUI project structure and design system.

THIRD:

Implement:

1. Authentication
2. Networking layer
3. Dashboard
4. Food scanner
5. Food analysis result
6. Meal saving/history
7. Nutrition goals
8. Workout tracking
9. Progress analytics
10. Community
11. Profile/settings

FOURTH:

Integrate the actual backend endpoints.

FIFTH:

Add tests and mock services.

SIXTH:

Perform a compile/test review and fix warnings/errors.

---

# 40. Cursor Coding Rules

Follow these rules throughout implementation:

- Prefer small reusable SwiftUI Views.
- Keep ViewModels focused.
- Do not put networking inside Views.
- Do not duplicate API request code.
- Do not duplicate design constants.
- Avoid force unwraps.
- Avoid force casts.
- Handle optional backend fields safely.
- Use dependency injection.
- Use protocols for API/service boundaries.
- Use async/await.
- Mark UI-bound observable state appropriately for Swift concurrency.
- Avoid retain cycles.
- Keep naming descriptive.
- Add comments only where they explain non-obvious logic.
- Do not add unnecessary packages.
- Prefer Apple frameworks.

---

# 41. Definition of Done

The frontend is complete when:

- The project opens and builds in Xcode.
- Login/register works against the actual backend.
- Authentication persists correctly.
- User can take/select a food image.
- Food image uploads to the correct backend endpoint.
- AI analysis result is displayed correctly.
- User can review and save the meal.
- Dashboard updates after saving.
- Nutrition goals can be loaded/saved where supported.
- Workouts can be created/listed where supported.
- Progress charts display backend data.
- Community data loads where supported.
- Profile/settings work where supported.
- Errors are handled cleanly.
- Loading and empty states exist.
- Dark mode works.
- Accessibility basics work.
- Unit tests exist for core services.
- Mock services are available for UI development.
- No secrets are committed.
- No fake backend endpoints are silently used.
- The app does not claim success before server confirmation.

---

# 42. Final Instruction to Cursor

Build this as a polished production-grade native iOS frontend for NutriScan.

The existing backend is the source of truth.

Before coding the API layer, inspect the backend repository thoroughly and map its real contracts.

When this PRD describes a capability conceptually but the backend uses a different route or schema, adapt the frontend to the backend rather than changing the product wording.

When this PRD requests a feature that the backend does not currently provide:

1. Keep the UI architecture ready for that feature.
2. Create a protocol/service boundary.
3. Create a mock implementation where useful.
4. Clearly mark the integration as backend-dependent.
5. Do not invent production API contracts.

The final result should look and feel like a serious App Store-quality nutrition and fitness application, with the photo-to-nutrition flow as its defining feature.
