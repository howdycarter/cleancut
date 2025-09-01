# TheSwiftKit (Phase 0 Scaffold)

This repository contains the initial scaffolding for a SwiftUI-first starter app generator. The code is structured to support modular features, backend adapters, and compliance-friendly defaults.

- iOS 16+, Xcode 15+, Swift 5.9+
- SwiftUI + MVVM-lite
- DI container, router, design tokens, and placeholders for Home/Settings

## Structure

```
Config/
Core/
  DI/
  Logging/
  Routing/
  Theme/
  Root/
Modules/
  Home/
  Settings/
Backend/
  Protocols/
Resources/
Tests/
```

## Setup

1) Duplicate `Config/Secrets.sample.swift` to `Config/Secrets.swift` and fill values.
2) Generate the Xcode project with XcodeGen (see below) and open it.
3) Select a Team for signing, then Build & Run.

## Tokens

The following placeholders will be replaced by the generator at export time:
- `__APP_NAME__`, `__BUNDLE_ID__`, `__PRIMARY_COLOR__`, `__ACCENT_COLOR__`
- `__PRIVACY_URL__`, `__TERMS_URL__`, `__BACKEND__` (supabase|local)
- `__FEATURE_ONBOARDING__`, `__FEATURE_AUTH__`, `__FEATURE_PAYWALL__`, etc.

## Notes

- Phase 0 focuses on foundations only; feature modules arrive in later phases.
- Tests are stubbed minimally to validate DI and routing wiring without network.

## XcodeGen

This repo includes `project.yml`. To generate and open the Xcode project:

1. Install XcodeGen (Homebrew): `brew install xcodegen`
2. From the repo root: `xcodegen generate`
3. Open: `open TheSwiftKit.xcodeproj`
4. In Xcode, select a development Team under Signing for the `TheSwiftKit` target.
5. Choose an iOS 16+ simulator and run.

The project target/module name is `TheSwiftKit`. Bundle ID defaults to `com.theswiftkit.app` (change in `project.yml` if needed).
# the-swift-kit
