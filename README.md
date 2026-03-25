TheSwiftKit – SwiftUI App Template
=================================

Overview
--------
- TheSwiftKit is a production‑ready SwiftUI app template with modular features: onboarding, authentication, paywall/subscriptions, analytics, notifications, AI wrappers, settings, and local persistence.
- Goal: clone → paste keys → set app name/colors → run. No code rewrites required for the typical setup.

Requirements
------------
- Xcode 15+ and Swift 5.9+
- iOS 16+ target
- Optional provider accounts as needed:
  - Supabase (Auth, Database, Storage)
  - RevenueCat (IAP/Subscriptions)
  - TelemetryDeck (Analytics)
  - OpenAI (optional, for the AI backend)
- Optional tooling: Supabase CLI (Edge Functions), Python 3.10+ (local AI server)

Quick Start
-----------
1) Clone the repo and open `TheSwiftKit.xcodeproj`.
2) Duplicate `Config/Secrets.sample.swift` → `Config/Secrets.swift`, then fill your keys and URLs.
3) Set your branding and identity:
   - App name: `Config/AppConfig.swift` (`appName`)
   - Theme colors: `Core/Theme/DesignTokens.swift` (`primaryHex`, `accentHex`)
   - Bundle ID: `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`)
4) Add your app icons to `Resources/Assets.xcassets/AppIcon.appiconset`.
5) Optionally add an `AppLogo` image to `Resources/Assets.xcassets` for the in‑app logo.
6) Build and run. If keys are missing, the app falls back to safe no‑op services.

Configuration
-------------
- App config: `Config/AppConfig.swift`
  - `appName`: Display name used throughout the UI; localized strings containing `__APP_NAME__` are replaced at runtime.
  - `backend`: `.supabase` or `.local` (controls repository implementations selected by DI).
  - `layout`: `.list` or `.grid` (example option used by HomeView model).
  - `onboardingStyle`: `.carousel`, `.highlights`, `.minimal`.
  - `featureFlags`: Toggle modules (onboarding, auth, paywall, notifications).
  - `legal`: Privacy Policy and Terms URLs.
- Theme colors: `Core/Theme/DesignTokens.swift`
  - Set `primaryHex` and `accentHex` once to theme the entire app.
- Secrets: `Config/Secrets.swift` (created from the sample)
  - `supabaseURL`, `supabaseAnonKey`
  - `telemetryDeckAppID`
  - `revenueCatAPIKey`
  - `aiBackendBaseURLString` (default `http://127.0.0.1:5001`)
  - `accountDeletionURLString` (optional HTTPS endpoint)
  - Sign in with Apple placeholders (optional for future wiring)
- Bundle identifier
  - Central in `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER` (also editable via Xcode Signing).
- Assets
  - App Icon: `Resources/Assets.xcassets/AppIcon.appiconset`
  - App Logo (optional): Add `AppLogo` image used by `LogoView`.
- Localization
  - Strings: `Resources/Base.lproj/Localizable.strings`.
  - Tokens containing `__APP_NAME__` are replaced with `AppConfig.appName` at runtime.

Feature Reference
-----------------
- Onboarding
  - Three styles controlled by `AppConfig.onboardingStyle` (carousel, highlights, minimal).
  - Uses `OnboardingPage` models and `.defaultPages` in `Modules/Onboarding/OnboardingModels.swift`.
- Authentication & Profile
  - Email/password via `AuthRepository` adapters selected by DI:
    - Supabase: `Backend/Supabase/SupabaseAuthRepository.swift`
    - Local fallback: `Backend/Protocols/AuthRepository.swift` (`LocalAuthRepository`)
  - If the user’s profile is missing, the app presents `ProfileSetupView` to capture name/gender/contact/avatar (Supabase or in‑memory local).
  - Sign in with Apple button is visible but disabled by default; enable once your Apple config is ready.
- Paywall & Subscriptions
  - UI: `Modules/Paywall/PaywallView.swift`
  - Service: `Core/Services/PurchasesService.swift`
    - RevenueCat implementation when the SDK is linked and `Secrets.revenueCatAPIKey` is set.
    - Noop implementation otherwise (UI stays functional with placeholder offerings).
  - Root integrates entitlement status via notifications posted by the purchases service.
- Analytics
  - `Core/Analytics/AnalyticsService.swift` selects TelemetryDeck v2 or TelemetryClient v1 when available and configured; otherwise Noop.
- Notifications (Debug)
  - `Modules/Notifications/NotificationsDebugView.swift` for permission requests, scheduling local notifications, APNs registration, and token display.
  - Service: `Core/Notifications/NotificationService.swift`.
- AI Wrappers (optional)
  - Home tabs for Text Generation (Chat), Image Generation, and Vision.
  - Client: `Core/Services/AIApiClient.swift` → your Flask backend (`Secrets.aiBackendBaseURL`).
- Local Data Demo
  - `Modules/Demo/LocalDataDemoView.swift` with `LocalCoreDataRepository` and `CoreDataStack` demonstrates a small programmatic Core Data model and CRUD.
- Theming
  - Set colors once in `DesignTokens`; `AppTheme` injected at root with an optional glass style used by components.
- Routing & DI
  - `Core/Routing/AppRouter.swift` (typed enum routes) and `Core/DI/DIContainer.swift` (selects adapters based on config and available SDKs).
- Logging
  - `Core/Logging/Logger.swift` for lightweight debug logging.
- Localization details
  - `Core/Utils/Localization.swift` includes a helper that replaces `__APP_NAME__` in localized strings with your configured app name.

Backend Setup
-------------
- Supabase (Auth, Profiles, Avatars)
  - Profiles table and RLS: Create `public.profiles` and allow users to read/update their own row.
  - Storage: Create an `avatars` bucket and add select/insert/update policies for authenticated users (public read if desired).
  - iOS: `SupabaseProfileRepository` reads/writes profiles and uploads avatars.
- Subscriptions mirror (optional but recommended)
  - SQL: Run `Backend/Supabase/sql/001_user_subscriptions.sql` and `002_user_subscriptions_enhancements.sql`.
  - Edge Function: Deploy `Backend/Supabase/edge/user_subscriptions_webhook.ts` to upsert rows from RevenueCat webhook events.
- RevenueCat
  - Configure products and offerings in the dashboard; paste the public API key in `Secrets.revenueCatAPIKey`.
  - Recommended: consider disabling automatic transfer of purchases to new App User IDs to avoid cross‑account restore issues.
- AI Backend (Flask)
  - Install dependencies: `pip install -r Backend/Python/requirements.txt`
  - Add your `.env` (ignored by git) with `OPENAI_API_KEY=sk-...` (and optional `OPENAI_BASE_URL`, model overrides).
  - Start: `python Backend/Python/app.py` (default port 5001). Health: `GET /health` → `{ "ok": true }`.
  - iOS: set `Secrets.aiBackendBaseURLString` to your server origin; `Info.plist` includes ATS exceptions for localhost during development.

Development Tips
----------------
- TestDrive (DEBUG only): `Modules/Demo/TestDriveView.swift` provides shortcuts to force onboarding, open settings, present paywall, view rating prompt, etc.
- Force onboarding once: set `forceOnboardingOnce` to true via TestDrive.
- SIWA: The Sign in with Apple button is present but `.disabled(true)` by default; enable after wiring your Apple credentials.

Troubleshooting
---------------
- Packages fail to resolve: ensure Xcode 15+; clean DerivedData and retry.
- Supabase errors: verify URL/key; confirm RLS policies; test queries in the SQL editor.
- RevenueCat entitlements: verify offerings and sandbox account; check the RC dashboard; relaunch app to refresh cache.
- AI backend: confirm `OPENAI_API_KEY` in `.env`; verify `/health`; inspect Flask logs.
- ATS/network: for dev on 127.0.0.1 and localhost, Info.plist contains the required exceptions.

Production Checklist
--------------------
- Replace legal URLs with your actual Privacy Policy and Terms.
- Provide final app icons and optional `AppLogo` image.
- Hide or remove debug/testing screens from release builds.
- Tighten storage and database policies (consider signed URLs, least‑privilege RLS).
- Keep real secrets out of git; manage per‑environment secrets via CI/CD.

File Map – Edit Points
----------------------
- Secrets: `Config/Secrets.swift` (copied from `Secrets.sample.swift`)
- App config: `Config/AppConfig.swift`
- Theme colors: `Core/Theme/DesignTokens.swift`
- Bundle ID: `project.yml` or Xcode Signing
- Assets: `Resources/Assets.xcassets/*`
- Localized copy: `Resources/Base.lproj/Localizable.strings`
