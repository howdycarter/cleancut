//
//  NotificationsDebugView.swift
//

import SwiftUI
import UserNotifications

struct NotificationsDebugView: View {
    @StateObject private var svc = NotificationService.shared
    @State private var lastStatus: String = ""
    @State private var scheduledCount: Int = 0

    var body: some View {
        List {
            Section("notif.status") {
                HStack {
                    Label(statusText, systemImage: statusIcon)
                    Spacer()
                    Text("notif.scheduled.count \(scheduledCount)")
                        .foregroundColor(.secondary)
                }
            }

            Section("notif.permissions") {
                Button("notif.request") { requestAuth() }
                Button("notif.open.settings") { svc.openSystemSettings() }
            }

            Section("notif.local") {
                Button("notif.schedule.5s") { schedule5s() }
                Button("notif.schedule.actions") { scheduleWithActions() }
                Button("notif.clear.pending") { Task { await svc.clearAllPending(); await refresh() } }
            }

            Section("notif.remote") {
                Button("notif.register.apns") { svc.registerForRemoteNotifications() }
                if let token = svc.lastDeviceTokenHex {
                    Text(token).appFont(.footnote).textSelection(.enabled)
                }
            }
        }
        .navigationTitle(Text("notif.debug.title"))
        .task { await refresh() }
        .onReceive(svc.$authorizationStatus) { _ in Task { await refresh() } }
    }

    private var statusText: String {
        switch svc.authorizationStatus {
        case .authorized: return NSLocalizedString("notif.status.authorized", comment: "")
        case .denied: return NSLocalizedString("notif.status.denied", comment: "")
        case .ephemeral: return NSLocalizedString("notif.status.ephemeral", comment: "")
        case .provisional: return NSLocalizedString("notif.status.provisional", comment: "")
        case .notDetermined: fallthrough
        @unknown default: return NSLocalizedString("notif.status.undetermined", comment: "")
        }
    }
    private var statusIcon: String {
        switch svc.authorizationStatus {
        case .authorized: return "checkmark.seal.fill"
        case .denied: return "xmark.seal.fill"
        case .ephemeral, .provisional: return "clock.badge.checkmark"
        case .notDetermined: fallthrough
        @unknown default: return "questionmark.circle"
        }
    }

    private func requestAuth() {
        Task {
            _ = try? await svc.requestAuthorization()
            await refresh()
        }
    }
    private func schedule5s() {
        Task {
            try? await svc.scheduleLocal(title: NSLocalizedString("notif.sample.title", comment: ""),
                                         body: NSLocalizedString("notif.sample.body", comment: ""),
                                         secondsFromNow: 5)
            await refresh()
        }
    }
    private func scheduleWithActions() {
        Task {
            svc.registerDefaultCategories()
            try? await svc.scheduleLocal(title: NSLocalizedString("notif.sample.actions.title", comment: ""),
                                         body: NSLocalizedString("notif.sample.actions.body", comment: ""),
                                         secondsFromNow: 5,
                                         categoryIdentifier: "demo.category")
            await refresh()
        }
    }
    private func refresh() async {
        await svc.refreshAuthorizationStatus()
        let list = await svc.listPending()
        await MainActor.run { scheduledCount = list.count }
    }
}

