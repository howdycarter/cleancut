//
//  AIApiClient.swift
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct AIApiClient: Sendable {
    struct ChatMessage: Codable, Sendable { let role: String; let content: String }
    struct ChatReply: Codable, Sendable { let reply: String }
    struct ImagesResponse: Codable, Sendable { let images: [String] }
    struct VisionResponse: Codable, Sendable { let result: String }

    var baseURL: URL
    init(baseURL: URL = Secrets.aiBackendBaseURL) { self.baseURL = baseURL }

    func sendChat(messages: [ChatMessage], model: String = "gpt-4o-mini", temperature: Double = 0.7) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/chat"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["messages": messages.map { ["role": $0.role, "content": $0.content] },
                                   "model": model,
                                   "temperature": temperature]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.assertOK(resp)
        let decoded = try JSONDecoder().decode(ChatReply.self, from: data)
        return decoded.reply
    }

    func generateImages(prompt: String, count: Int = 4, size: String = "512x512") async throws -> [Data] {
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/images"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["prompt": prompt, "count": count, "size": size, "response_format": "b64_json"]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.assertOK(resp)
        let decoded = try JSONDecoder().decode(ImagesResponse.self, from: data)
        return decoded.images.compactMap { Data(base64Encoded: $0) }
    }

    func visionAnalyze(imageData: Data, prompt: String? = nil) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/vision"))
        req.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func appendField(_ name: String, value: String) {
            if let d = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8) {
                body.append(d)
            }
        }
        func appendFile(_ name: String, filename: String, mime: String, data: Data) {
            var header = "--\(boundary)\r\n"
            header += "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
            header += "Content-Type: \(mime)\r\n\r\n"
            body.append(header.data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }
        if let prompt, !prompt.isEmpty { appendField("prompt", value: prompt) }
        appendFile("file", filename: "image.jpg", mime: "image/jpeg", data: imageData)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.assertOK(resp)
        let decoded = try JSONDecoder().decode(VisionResponse.self, from: data)
        return decoded.result
    }

    private static func assertOK(_ resp: URLResponse) throws {
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "AIAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned \(http.statusCode)"])
        }
    }
}

