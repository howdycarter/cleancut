# CleanCut build and monetization preparation

This branch is a local preparation build. No App Store products, prices, subscriptions, business account settings, or releases have been published. The intended seller is **Newton & Carter LLC**; updating the Apple account and signing are deferred at the owner’s request.

## Building

Open `CleanCut.xcodeproj` and select the `CleanCut` scheme. The tracked `Config/ServiceConfiguration.swift` supplies empty optional integration values, so a clean checkout builds without a credentials file. The original bundle identifier is preserved. The shared scheme uses a local StoreKit configuration for interactive debug purchases; archive/release uses App Store products. Run the unit tests with normal simulator signing (an ad hoc identity is sufficient); disabling code signing prevents local StoreKit product loading on this Xcode runtime.

Set public service identifiers through Info.plist only when the corresponding service is configured. Native StoreKit 2 is the purchase provider by default. A configured RevenueCat public client key selects the existing RevenueCat provider. No private keys belong in this app.

## Paid features

Free: on-device background removal and transparent/white/black PNG exports up to 1024 pixels. Pro: original-resolution PNG exports and custom background colors.

Product identifiers are in `Secrets.storeProductIdentifiers`. Prices come from Apple's localized product data. The fixture `Tests/Fixtures/CleanCut.storekit` contains **unapproved test prices**, copied from pre-existing demo values only for local validation. They are not a pricing recommendation or evidence that any live product exists. The existing CleanCut product identifiers are preserved; their corresponding App Store Connect configuration still needs verification before release.

The provider verifies transactions, observes updates, restores Apple purchases, and removes access after revocation. Missing products leave the free app usable. The paywall states recurring billing and presents restore and close controls.

## Release gates still open

- Choose and approve real pricing and create matching products in App Store Connect.
- Review the final privacy declarations for whichever optional integrations are enabled. The bundled manifest currently declares the app's private UserDefaults use; it does not replace App Store privacy answers.
- Verify camera capture, background segmentation, and the full edit/save/share flow on a physical iPhone. The iOS simulator photo picker works, but Vision could not create an inference context, including when supported CPU stages were requested. No end-to-end segmentation success is claimed from the simulator.
- Sign the final build and perform a sandbox/TestFlight purchase and restore rehearsal before submission.

The app-specific icon prompt and provenance are in `AppIcon-Prompt.md`.

## Validation

- Xcode 27 / iOS 27 simulator: 15 unit and local StoreKit integration tests passed. Coverage includes PNG transparency, image orientation, original pixel dimensions, custom backgrounds, and the free/Pro export boundary.
- StoreKit tests exercise localized products, actual test purchases, restoring into a fresh service, asynchronous refund revocation, and unknown-product rejection.
- A generic iOS Release archive builds without a signing identity. Signing remains deferred.
- Generated icons are opaque 1024 × 1024 assets; in-app logos use the full-resolution source and respect Reduce Motion.

Local StoreKit success does not verify App Store Connect, Apple’s sandbox, or a production transaction. The RevenueCat path remains optional and needs its own configured-project validation if enabled.

The setup wizard now writes public runtime service values into `Resources/Info.plist`, which `Config/ServiceConfiguration.swift` reads. The legacy ignored `Secrets.swift` is not compiled. Do not enter server secrets or private signing keys. XcodeGen preserves the local StoreKit fixture through `project.yml`.

Release identity clarification: `com.chriscarterux.cleancut` was already the app target bundle identifier in the original Xcode project. The stale `com.cleancut.app` template value in AppConfig was aligned to that existing target; no App Store bundle identity migration is requested.

## Published support and privacy

The app links to the [privacy policy](https://howdycarter.com/apps/cleancut/privacy) and [Apple standard terms](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/). The [support page](https://howdycarter.com/apps/cleancut/support) is ready for App Store Connect metadata. The privacy and support routes were checked live on October 13, 2026. These pages describe the default local build; enabling an optional service requires reviewing the policy and App Store declarations again.

Business support and App Review contact: [chris@newtonandcarter.com](mailto:chris@newtonandcarter.com), Newton & Carter LLC.
