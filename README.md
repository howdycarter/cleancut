AI Prompt Specification – SwiftUI App Generator (SaaS) v1.0
Author: Ahmed Gagan · Purpose: This document tells an AI assistant everything about the product and gives step-by-step, phase-wise prompts so output is correct on the first try.
0) Product Vision & Scope
What we’re building
- A SaaS that lets iOS developers generate a ready-to-run SwiftUI app codebase in one click, with configurable modules (onboarding, auth, paywalls, backend connectors, settings, etc.).
- Output is a clean Xcode project using SwiftUI + Swift, MVVM-lite, modern concurrency, and first-class App Store compliance baked in.
- Users pick features in a web UI, set branding, choose a backend, and download a zipped project that builds & runs immediately.

Target users
- Indie iOS devs and small teams using SwiftUI who want to skip boilerplate.
- Agencies that need consistent, compliant starting points.

Non-goals (for initial versions)
- No custom server provisioning. We integrate with third-party backends (Supabase) or local storage only.
- No UIKit-only code (SwiftUI-first; UIKit only when unavoidable).
- No code obfuscation or DRM.

Success criteria
- A new user can generate, open, and run a project in ≤ 5 minutes.
- Project passes a baseline App Store review checklist (restore purchases, Sign in with Apple rules, permission strings).
- Modules are add/remove without breaking the build.

Supported targets
- iOS 16+ (minimum), Xcode 15+, Swift 5.9+.
1) Architecture Overview
- Project structure is modular with Config, Core, Modules, Backend, Resources, and Tests directories.
- Uses MVVM-lite: Views for layout, ViewModels for state and logic, Repositories for backend abstraction.
- Dependency injection handled by a lightweight DIContainer.
- Navigation via AppRouter with NavigationStack.
- Design tokens for colors, fonts, spacing.
- Secrets handled via Secrets.swift populated from web UI configs.
2) App Store Compliance (baked in)
- Restore Purchases button on paywall.
- Sign in with Apple required if other sign-ins exist.
- Privacy Policy & Terms screens included with configurable links.
- Permission usage strings prefilled in Info.plist.
- Account deletion path provided if accounts exist.
- Legal placeholders included, developer must replace with actual links.
3) Database / Backend Support Plan
Abstraction approach
- Define repository protocols (AuthRepository, UserRepository, etc.).
- Concrete adapters for each backend, switched via AppConfig.backend.

Backends supported (MVP)
1. Supabase: Postgres, REST & Realtime, Auth, Storage, Swift client.
2. Local (Core Data): offline persistence, no setup required.

Deferred: Firebase, Realm, Hasura, Appwrite, PocketBase.

Recommendation for v1: Ship Supabase + Local only.

Config shape:
enum BackendProvider: String { case supabase, local }
AppConfig.backend = .supabase // or .local

Secrets
- Secrets.sample.swift with placeholders → user duplicates to Secrets.swift.
- All keys/configs collected in web UI step; generated project wired automatically.
4) Conventions & Guardrails for AI Outputs
- SwiftUI only, UIKit only if unavoidable.
- Modern Swift: async/await, @MainActor.
- No TODOs or stubs; must compile clean.
- Tests included: minimal but working.
- Strings in Localizable.strings.
- Design tokens for colors/fonts, no inline literals.
- One major type per file, proper folder structure.
- Each file includes header comments.
5) Phase Plan
Phase 0 — Foundations & Scaffolding
- Create AppConfig.swift, FeatureFlags.swift, Secrets.sample.swift.
- Add Theme + DesignTokens, AppRouter, RootView, DIContainer, Logger.
- Provide empty tabbed app with placeholders for Home, Settings.

Phase 1 — Core UI Shell (Home + Detail + Navigation)
- Add HomeView and DetailView with mock data.
- Support list or grid via AppConfig.
- NavigationStack pushes to DetailView.

Phase 2 — Onboarding Module Library
- Include pre-coded onboarding templates (carousel, highlights, minimal).
- Controlled via AppConfig.onboardingStyle enum.
- Uses AppStorage("hasSeenOnboarding").

Phase 3 — Authentication
- Support Email/Password + Sign in with Apple.
- Supabase backend only in v1.
- Provide AuthRepository + Supabase adapter.

Phase 4 — Paywall & StoreKit 2
- Subscription paywall with product fetch, purchase, restore.
- Restore button mandatory, sandbox-friendly.

Phase 5 — Backend Data
- Implement UserRepository, ItemRepository.
- Supabase + Local adapters.

Phase 6 — Settings, Legal, Account Deletion
- SettingsView with theme toggle, account deletion, legal links.

Phase 7 — Notifications
- APNs integration, user consent prompt, DebugView logs.
- No Firebase FCM in v1.

Phase 8 — Packaging & Code Generation (CLI)
- CLI tool assembles modules, injects secrets/configs, outputs Xcode project.

Phase 9 — SaaS Web UI & Orchestrator
- React/Next.js frontend to collect configs + features.
- Backend orchestrator generates and returns zipped project.

Phase 10 — QA & Sample Apps
- Compliance checklist and sample presets (Notes app, Catalog app).
6) Detailed Specs for Key Files
- AppConfig.swift: appName, backend, branding, layout, feature flags.
- Secrets.swift: Supabase keys.
- DesignTokens.swift: central theme constants.
- AppRouter.swift: navigation enum + router logic.
- Repositories/: Supabase + Local implementations only.
7) Localization & Accessibility Rules
- All strings in Localizable.strings.
- VoiceOver labels for tappable elements.
- Dynamic Type support for accessibility.
- Respect reduced motion settings.
8) Testing Strategy
- Unit tests for repositories and view models.
- UI tests for onboarding, auth, paywall.
- No external network calls in tests.
9) Deliverables & Definition of Done
- Compiles on iOS 16+ with Xcode 15+.
- Pre-configured with secrets from web UI.
- Test target included.
- README with setup instructions.
10) Ready-Made Variable Tokens
- __APP_NAME__, __BUNDLE_ID__, __PRIMARY_COLOR__, __ACCENT_COLOR__.
- __PRIVACY_URL__, __TERMS_URL__, __BACKEND__ (supabase|local).
- __FEATURE_ONBOARDING__, __FEATURE_AUTH__, __FEATURE_PAYWALL__, etc.
11) Developer Experience (DX) Notes
- Secrets provided once via web UI, auto-injected in codebase.
- Generated project runs immediately.
- Local backend used if Supabase not configured.
12) Future Extensions (post-MVP)
- Add Firebase, Realm, Hasura, Appwrite.
- Add more screen templates (chat, maps, camera, ARKit).
- Add analytics providers and theme packs.
- Marketplace for templates and plugins.
13) How to Use This Document (for AI)
- Treat each Phase section’s Prompt as exact instruction.
- Always respect conventions and guardrails.
- Never skip acceptance criteria.
- Generate clean, compilable SwiftUI code with required mocks if needed.

============================================================
Current Progress (Dev Log)
============================================================

Summary
- Sign-in UX fixed and instrumented; added profile onboarding backed by Supabase with avatar upload. iOS 16-compatible navigation and required plist strings added.

Auth and UX changes
- Sign-in button: Enabled when email and password are non-empty (was 6+ chars). File: Modules/Auth/SignInView.swift:90
- Sign-in result: Presents alert on success/failure for quick validation. File: Modules/Auth/SignInView.swift:26
- Startup log: Prints "Auth status: Logged In/Logged Out" on launch in Debug. File: Core/Root/RootView.swift:56

Profile system (reusable template)
- Domain + protocol: Profile model, Gender enum, and ProfileRepository protocol. File: Backend/Protocols/ProfileRepository.swift:1
- Supabase adapter: Reads/writes `public.profiles`, uploads avatar to `avatars` bucket, returns public URL. File: Backend/Supabase/SupabaseProfileRepository.swift:1
- DI wiring: `DIContainer` now exposes `profileRepository` and selects Local or Supabase by `AppConfig.backend`. File: Core/DI/DIContainer.swift:7
- UI flow: After first sign-in without a profile, present a profile form (name, gender, contact, avatar picker) and save. File: Modules/Profile/ProfileSetupView.swift:1
- Routing: iOS 16-friendly `.sheet(item:)` presents profile setup after sign-in. File: Modules/Auth/AuthCoordinator.swift:1
- Photos permission: Added `NSPhotoLibraryUsageDescription`. File: Resources/Info.plist:15

Xcode project updates
- Registered new files in app target so they compile:
  - Backend/Protocols/ProfileRepository.swift
  - Backend/Supabase/SupabaseProfileRepository.swift
  - Modules/Profile/ProfileSetupView.swift

Supabase prerequisites (run once)
- Profiles table and policies:
  - create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    name text, gender text, contact text, avatar_url text,
    updated_at timestamptz default now()
  );
  - alter table public.profiles enable row level security;
  - create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);
  - create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
  - create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
- Storage bucket and policies (simple public read):
  - insert into storage.buckets (id, name, public) values ('avatars','avatars', true) on conflict do nothing;
  - create policy "avatars_public_read" on storage.objects for select using (bucket_id = 'avatars');
  - create policy "avatars_user_insert" on storage.objects for insert to authenticated with check (bucket_id = 'avatars');
  - create policy "avatars_user_update" on storage.objects for update to authenticated using (bucket_id = 'avatars');
- Secrets: `Config/Secrets.swift` must point to your Supabase project (URL + anon key).

How to test quickly
- Sign in with Supabase backend (Config/AppConfig.swift:72 is `.supabase`).
- If profile is missing, a sheet opens to capture name/contact/avatar. Tap Save.
- On success, sheet dismisses and app proceeds. On failure, you see the Supabase error message.
- For offline UI testing, switch to `.local` backend; profiles are in-memory and uploads return a fake URL.

Known considerations / next steps
- Display profile and avatar in Settings and Home.
- Use signed URLs instead of public for avatars if bucket is private.
- Add lightweight client-side validation to the profile form.
- Persist local-auth sessions (Keychain) when using `.local` backend.
- Provide SQL migrations in a `/Supabase` folder for one-click setup.
