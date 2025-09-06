//
//  AccountDeletionService.swift
//

import Foundation

enum AccountDeletionService {
    struct Request: Codable { let userId: String; let email: String }

    static func requestDeletionIfConfigured(userId: String, email: String) async {
        guard let url = Secrets.accountDeletionURL else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(Request(userId: userId, email: email))

        _ = try? await URLSession.shared.data(for: req)
    }
}

