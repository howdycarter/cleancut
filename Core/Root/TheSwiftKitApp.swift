//
//  TheSwiftKitApp.swift
//

import SwiftUI
import UserNotifications

@main
struct CleanCutApp: App {
    @StateObject private var router = AppRouter()
    private let container = DIContainer.makeDefault()
    #if DEBUG
    @State private var showTester: Bool = true
    #endif

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("appThemeStyle") private var themeStyleRaw: String = DS.surfaceStyle.rawValue
    @AppStorage("appearanceDark") private var appearanceDark: Bool = false
    @AppStorage("appearanceLocked") private var appearanceLocked: Bool = false

    init() {
        // Initialize analytics as early as possible
        container.analytics.configure()
        container.analytics.track("App.Launch")

        // Start cache auto-invalidation listener (clears cache on sign-out).
        // Safe to call multiple times; only the first call registers observers.
        if container.config.featureFlags.enableCaching {
            CacheInvalidationObserver.shared.startListening()
        }
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            Group {
                if showTester {
                    TestDriveView(continueAction: { route in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTester = false
                        }
                        if let route {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    router.push(route)
                                }
                            }
                        }
                    })
                } else {
                    RootView()
                }
            }
            .inject(container)
            .environmentObject(router)
            .dsTheme(DSTheme(surfaceStyle: SurfaceStyle(rawValue: themeStyleRaw) ?? DS.surfaceStyle))
            .preferredColorScheme(appearanceLocked ? (appearanceDark ? .dark : .light) : nil)
            .task {
                // Configure RevenueCat early and refresh entitlements on launch
                container.purchasesService.configure()
                await container.purchasesService.refreshSubscriptionStatus()
            }
            #else
            RootView()
                .inject(container)
                .environmentObject(router)
                .dsTheme(DSTheme(surfaceStyle: SurfaceStyle(rawValue: themeStyleRaw) ?? DS.surfaceStyle))
                .preferredColorScheme(appearanceLocked ? (appearanceDark ? .dark : .light) : nil)
                .task {
                    // Configure RevenueCat early and refresh entitlements on launch
                    container.purchasesService.configure()
                    await container.purchasesService.refreshSubscriptionStatus()
                }
            #endif
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            NotificationService.shared.setDeviceToken(deviceToken)
        }
    }
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error)")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NotificationService.shared.handleBackgroundRemoteNotification(userInfo: userInfo, completion: completionHandler)
    }
}
