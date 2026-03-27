<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="The Swift Kit" />
</p>

<h1 align="center">The Swift Kit</h1>

<p align="center">
  <strong>A production-ready SwiftUI app template for shipping iOS apps fast.</strong>
</p>

<p align="center">
  Clone. Paste your keys. Ship.<br/>
  Auth, payments, AI, onboarding, analytics — all wired up and ready to go.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.9+-F05138?style=flat&logo=swift&logoColor=white" alt="Swift 5.9+" />
  <img src="https://img.shields.io/badge/iOS-16+-000000?style=flat&logo=apple&logoColor=white" alt="iOS 16+" />
  <img src="https://img.shields.io/badge/Xcode-15+-147EFB?style=flat&logo=xcode&logoColor=white" alt="Xcode 15+" />
  <img src="https://img.shields.io/badge/SwiftUI-4+-0A84FF?style=flat" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-Commercial-8A2BE2?style=flat" alt="License" />
</p>

---

## Quick Start

The fastest way to get running — one script configures everything:

```bash
chmod +x setup.sh
./setup.sh
```

The interactive setup wizard walks you through app name, bundle ID, theme colors, API keys, and legal URLs. It replaces every placeholder across the project and generates `Config/Secrets.swift` automatically.

For CI or non-interactive usage:

```bash
./setup.sh --config setup-config.json
```

Then open the project in Xcode, select your team under Signing, and hit Run.

---

## What's Included

| Module | Description | Key Files |
|--------|-------------|-----------|
| **Authentication** | Email/password + Sign in with Apple via Supabase | `Modules/Auth/` |
| **Onboarding** | 3 swappable styles (Carousel, Highlights, Minimal) | `Modules/Onboarding/` |
| **Paywalls** | RevenueCat + StoreKit 2 integration with paywall UI | `Modules/Paywall/` |
| **AI Features** | Chat, image generation, and vision via Flask backend | `Modules/Home/`, `Backend/Python/` |
| **Analytics** | TelemetryDeck with automatic event tracking | `Core/Analytics/` |
| **Notifications** | Local + remote push notifications with debug UI | `Core/Notifications/` |
| **Profile Setup** | Avatar upload, user data capture, Supabase storage | `Modules/Profile/` |
| **Settings** | Dark mode, subscription management, account deletion | `Modules/Settings/` |
| **Caching** | Ultra-modular, actor-based caching system | `Core/Cache/` |
| **Custom Fonts** | Drop-in font infrastructure with centralized typography | `Core/Theme/` |
| **Theming** | Design tokens, color system, glass effects | `Core/Theme/` |
| **Local Data** | CoreData demo with full CRUD | `Modules/Demo/` |

---

## Project Structure

```
the-swift-kit/
├── Config/                         # App configuration
│   ├── AppConfig.swift             # App name, backend, feature flags, legal URLs
│   ├── FeatureFlags.swift          # Toggle any module on/off
│   └── Secrets.sample.swift        # API key template (copy to Secrets.swift)
│
├── Core/                           # Core infrastructure
│   ├── Cache/                      # Modular caching system (actor-based)
│   ├── DI/                         # Dependency injection container
│   ├── Routing/                    # Navigation router (typed enum routes)
│   ├── Services/                   # AI client, purchases, Apple Sign-In
│   ├── Theme/                      # Design tokens, colors, typography, fonts
│   ├── Analytics/                  # Analytics service wrapper
│   ├── Notifications/              # Push & local notification handling
│   ├── Persistence/                # CoreData stack
│   ├── Root/                       # App entry point & RootView
│   └── Utils/                      # Localization, app events
│
├── Modules/                        # Feature modules (screens)
│   ├── Auth/                       # Sign in, create account, coordinator
│   ├── Onboarding/                 # 3 onboarding styles + coordinator
│   ├── Home/                       # Main screen with AI feature tabs
│   ├── Paywall/                    # Subscription UI
│   ├── Profile/                    # Profile setup form
│   ├── Settings/                   # Settings, subscription mgmt, dark mode
│   ├── Notifications/              # Debug notification testing
│   └── Demo/                       # TestDrive shortcuts, local data, rating
│
├── Backend/                        # Server-side code & protocols
│   ├── Protocols/                  # Repository interfaces
│   ├── Supabase/                   # Supabase implementations + setup.sql
│   └── Python/                     # Flask AI backend (chat, images, vision)
│
├── Resources/                      # Assets, icons, fonts, localization
├── setup.sh                        # Interactive setup wizard
├── setup-config.json               # Non-interactive config template
└── project.yml                     # XcodeGen configuration
```

---

## Architecture

The Swift Kit follows **MVVM with Dependency Injection** and a protocol-first design:

```
SwiftUI View  →  ViewModel (@MainActor)  →  DIContainer  →  Repository Protocol  →  Backend Implementation
```

**Key design principles:**

- **Protocol-based repositories** — Every backend service (auth, profiles, subscriptions) has a protocol. Swap implementations by changing one line in `AppConfig`.
- **Feature flags** — Toggle any module (onboarding, auth, paywall, notifications, caching, Apple Sign-In) without touching code.
- **Conditional imports** — The project compiles even without Supabase, RevenueCat, or TelemetryDeck SDKs linked. Missing SDKs gracefully fall back to no-op implementations.
- **Actor-based concurrency** — All repositories and the caching layer use Swift actors for thread safety.
- **Centralized theming** — Change two hex values in `DesignTokens.swift` to rebrand the entire app. Swap fonts by editing `FontRegistry.swift`.

---

## Configuration

### App Config (`Config/AppConfig.swift`)

| Property | Description | Options |
|----------|-------------|---------|
| `appName` | Display name used throughout the UI | Any string |
| `backend` | Backend selection | `.supabase` or `.local` |
| `onboardingStyle` | Onboarding screen style | `.carousel`, `.highlights`, `.minimal` |
| `featureFlags` | Toggle modules on/off | See `FeatureFlags.swift` |
| `legal` | Privacy Policy and Terms URLs | Your production URLs |

### Feature Flags (`Config/FeatureFlags.swift`)

| Flag | Default | Description |
|------|---------|-------------|
| `enableOnboarding` | `true` | Show onboarding flow on first launch |
| `enableAuth` | `true` | Require authentication |
| `enablePaywall` | `true` | Show paywall after onboarding |
| `enableNotifications` | `true` | Request notification permissions |
| `appleSignIn` | `true` | Show Sign in with Apple button |
| `enableCaching` | `true` | Wrap repositories in cached decorators |

### Secrets (`Config/Secrets.swift`)

Created automatically by `setup.sh`, or manually from `Secrets.sample.swift`:

| Key | Required | Source |
|-----|----------|--------|
| `supabaseURL` | Yes | Supabase project settings |
| `supabaseAnonKey` | Yes | Supabase project settings |
| `revenueCatAPIKey` | Yes | RevenueCat dashboard |
| `telemetryDeckAppID` | Yes | TelemetryDeck dashboard |
| `aiBackendBaseURLString` | Optional | Your Flask server URL |

### Theming

- **Colors**: Set `primaryHex` and `accentHex` in `Core/Theme/DesignTokens.swift`
- **Fonts**: Edit `Core/Theme/FontRegistry.swift` to swap to custom fonts (see `Resources/Fonts/README.md`)
- **Typography**: All text styles go through `Core/Theme/Typography.swift` via the `.appFont()` modifier

---

## Backend Setup

### Database (Supabase)

One command sets up everything:

1. Open your Supabase project's **SQL Editor**
2. Paste the contents of `Backend/Supabase/setup.sql`
3. Click **Run**

This creates: `profiles` table, `user_subscriptions` table, Row Level Security policies, auto-create-profile-on-signup trigger, timestamp triggers, `avatars` storage bucket with policies, and indexes. Idempotent — safe to run multiple times.

### Sign in with Apple

See the detailed setup guide in `Core/Services/AppleSignInService.swift`. Summary:

1. Enable "Sign in with Apple" capability in Xcode
2. Configure your App ID in Apple Developer Portal
3. Enable Apple provider in Supabase Authentication dashboard
4. Set `featureFlags.appleSignIn = true`

### RevenueCat (Payments)

1. Create products and offerings in the [RevenueCat dashboard](https://app.revenuecat.com)
2. Paste your public API key in `Secrets.revenueCatAPIKey`
3. The paywall UI and subscription management work automatically

### AI Backend (Flask)

```bash
cd Backend/Python
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # Add your OPENAI_API_KEY
python app.py           # Runs on port 5001
```

Three endpoints: `/v1/chat` (GPT-4o), `/v1/images` (gpt-image-1.5), `/v1/vision` (GPT-4o multimodal).

See `Backend/Python/README.md` for full API docs and deployment instructions.

---

## Caching System

The Swift Kit includes a modular, actor-based caching layer. It's designed so you can add caching to any new feature in 3 steps:

**Step 1** — Define a cache key:
```swift
extension CacheKeys {
    static func postList(page: Int) -> String { "posts_list_page_\(page)" }
}
```

**Step 2** — Set an expiry (optional):
```swift
extension CacheConfig {
    static let postsExpiry: CacheExpiry = .minutes(10)
}
```

**Step 3** — Write a cached wrapper:
```swift
actor CachedPostsRepository: PostsRepository {
    private let remote: PostsRepository
    private let cache: CacheManager

    func fetchPosts(page: Int) async throws -> [Post] {
        let key = CacheKeys.postList(page: page)
        if let cached: [Post] = await cache.get(forKey: key) { return cached }
        let posts = try await remote.fetchPosts(page: page)
        await cache.set(posts, forKey: key, expiry: CacheConfig.postsExpiry)
        return posts
    }
}
```

Cache auto-clears on sign-out. Toggle the entire system via `featureFlags.enableCaching`.

---

## Custom Fonts

The default is the system font (SF Pro). To use custom fonts:

1. Drop `.ttf` or `.otf` files into `Resources/Fonts/`
2. Add filenames to `Info.plist` under `UIAppFonts`
3. Update `FontRegistry.swift` with your font's PostScript names:

```swift
public var postScriptName: String {
    switch self {
    case .regular:  return "Inter-Regular"
    case .medium:   return "Inter-Medium"
    case .semibold: return "Inter-SemiBold"
    case .bold:     return "Inter-Bold"
    }
}
```

The entire app updates automatically. All views use `.appFont()` instead of `.font()`.

Tip: Call `FontRegistry.logAvailableFonts()` to print every installed PostScript name.

---

## Development

### TestDrive (Debug Only)

`Modules/Demo/TestDriveView.swift` provides shortcuts for:
- Force onboarding replay
- Open settings directly
- Present paywall
- Test rating prompt
- View notification debug screen

### Debug Tips

- Set `backend: .local` in AppConfig to develop without Supabase
- All modules work with local fallbacks (no network required)
- `Info.plist` includes ATS exceptions for localhost during development

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Packages fail to resolve | Ensure Xcode 15+. Clean DerivedData (`Cmd+Shift+K`) and retry |
| Supabase errors | Verify URL/key in Secrets. Check RLS policies. Test queries in SQL Editor |
| RevenueCat issues | Verify offerings in RC dashboard. Check sandbox account. Relaunch to refresh cache |
| AI backend errors | Confirm `OPENAI_API_KEY` in `.env`. Check `/health` endpoint. Inspect Flask logs |
| Sign in with Apple | Follow the setup guide in `AppleSignInService.swift`. Check entitlements and provisioning |
| Build fails without SDKs | Expected — conditional imports gracefully fall back to no-op implementations |

---

## Production Checklist

- [ ] Run `./setup.sh` with production values
- [ ] Replace legal URLs with actual Privacy Policy and Terms
- [ ] Set up Supabase database (`setup.sql`)
- [ ] Configure RevenueCat products and offerings
- [ ] Configure Sign in with Apple (if using)
- [ ] Provide final app icons and optional AppLogo
- [ ] Deploy the AI Flask backend (if using AI features)
- [ ] Remove or hide TestDrive from release builds
- [ ] Review RLS policies and storage permissions
- [ ] Keep secrets out of git — use CI/CD for environment-specific config
- [ ] Test the full flow: onboarding → auth → profile → paywall → main app

---

## Changelog

### v1.2.0 — March 27, 2026

**Design System**
- Centralized 5-layer design system — edit `DesignSystem.swift` to retheme the entire app
- Five surface styles: Flat, Bordered, Elevated, Glass, Liquid Glass (iOS 26+ with automatic fallback)
- Brand color tokens, spacing density, corner radius, shadows, and motion tokens
- New DS building blocks: `DS.primary`, `DS.Spacing.md`, `.appFont()`, `.dsCard()`

**Interactive Setup CLI**
- New `./setup.sh` script — interactive CLI for project configuration
- Configures app name, brand colors, surface style, feature selection, backend, and API keys automatically
- Regenerates Xcode project — no manual file editing needed

**Feature Flags**
- Every major module gated by a boolean flag
- Modules: onboarding, authentication, paywall, notifications, AI features, Apple Sign-In
- Disabled features disappear completely from the app flow

**AI Features**
- ChatGPT chat with streaming responses via Flask proxy
- DALL-E image generation (gpt-image-1.5)
- GPT-4 Vision for image analysis
- Secure backend proxy — API key never touches the device

**Authentication**
- Sign in with Apple pre-wired (nonce generation, Supabase backend integration)
- Profile setup flow after first sign-in
- Graceful fallback when auth is disabled via feature flag

**Architecture**
- MVVM with dependency injection container
- Repository pattern with protocol-based abstractions
- Conditional SDK imports with no-op fallbacks for missing keys
- All SwiftUI previews working out of the box

### v1.1.0 — March 2026

- Added offline HTML documentation
- Updated README with comprehensive module guides
- Improved Supabase RLS policy templates

### v1.0.0 — February 2026

- Initial release: onboarding, auth, paywalls, analytics, AI wrappers, documentation

---

<p align="center">
  Built with care for indie iOS developers.<br/>
  <a href="https://theswiftk.it.com">theswiftk.it.com</a>
</p>
