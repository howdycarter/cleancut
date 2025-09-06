//
//  NotificationService.swift
//

import Foundation
import UserNotifications
import SwiftUI
import UIKit

@MainActor
public final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()

    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public private(set) var lastDeviceTokenHex: String?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Background Remote Handling
    public func handleBackgroundRemoteNotification(userInfo: [AnyHashable: Any], completion: @escaping (UIBackgroundFetchResult) -> Void) {
        // Parse and act on payload here. For now we just log and report no new data.
        print("Background remote notification: \(userInfo)")
        completion(.noData)
    }

    // MARK: - Authorization
    public func requestAuthorization(options: UNAuthorizationOptions = [.alert, .badge, .sound]) async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        await refreshAuthorizationStatus()
        return granted
    }

    public func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { self.authorizationStatus = settings.authorizationStatus }
    }

    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Categories & Actions
    public func registerDefaultCategories() {
        let like = UNNotificationAction(identifier: "like", title: "Like", options: [.foreground])
        let reply = UNTextInputNotificationAction(identifier: "reply", title: "Reply", options: [])
        let category = UNNotificationCategory(identifier: "demo.category", actions: [like, reply], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Scheduling (Local)
    public func scheduleLocal(identifier: String = UUID().uuidString,
                              title: String,
                              body: String,
                              secondsFromNow: TimeInterval = 5,
                              categoryIdentifier: String? = nil,
                              userInfo: [AnyHashable: Any] = [:]) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        if let categoryIdentifier { content.categoryIdentifier = categoryIdentifier }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, secondsFromNow), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    public func scheduleCalendar(identifier: String = UUID().uuidString,
                                 title: String,
                                 body: String,
                                 dateComponents: DateComponents,
                                 repeats: Bool = false) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    public func clearAllPending() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    public func listPending() async -> [UNNotificationRequest] {
        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
                continuation.resume(returning: reqs)
            }
        }
    }

    // MARK: - Remote (APNs)
    public func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    public func setDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        lastDeviceTokenHex = token
        print("APNs token: \(token)")
    }

    // MARK: - UNUserNotificationCenterDelegate
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Show banner/sound while app is in foreground for better testing visibility
        return [.banner, .sound, .list]
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse) async {
        print("Notification action: \(response.actionIdentifier)")
    }
}
