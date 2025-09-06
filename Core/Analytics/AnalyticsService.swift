//
//  AnalyticsService.swift
//  TheSwiftKit
//

import Foundation

public protocol AnalyticsService: Sendable {
    func configure()
    func track(_ name: String, properties: [String: String])
    func identify(userID: String?)
}

public extension AnalyticsService {
    func track(_ name: String) { track(name, properties: [:]) }
    func identify(userID: String?) {}
}

// MARK: - Noop Implementation (safe default)

public struct NoopAnalyticsService: AnalyticsService {
    public init() {}
    public func configure() {
        #if DEBUG
        print("[Analytics] NoopAnalyticsService configured (no App ID set)")
        #endif
    }
    public func track(_ name: String, properties: [String: String]) {
        #if DEBUG
        print("[Analytics] (noop) \(name) \(properties)")
        #endif
    }
}

// MARK: - TelemetryDeck-backed Implementation

#if canImport(TelemetryDeck)
import TelemetryDeck

public final class TelemetryDeckAnalyticsService: AnalyticsService {
    private let appID: String?
    private var isConfigured = false

    public init(appID: String?) { self.appID = appID?.trimmingCharacters(in: .whitespacesAndNewlines) }

    public func configure() {
        guard !isConfigured, let appID, !appID.isEmpty else { return }
        var config = TelemetryDeck.Config(appID: appID)
        #if DEBUG
        config.testMode = true
        #endif
        TelemetryDeck.initialize(config: config)
        #if DEBUG
        print("[Analytics] TelemetryDeck v2 configured (testMode=\(config.testMode))")
        #endif
        isConfigured = true
    }

    public func track(_ name: String, properties: [String: String]) {
        guard isConfigured else {
            #if DEBUG
            print("[Analytics] Skipped (not configured): \(name)")
            #endif
            return
        }
        TelemetryDeck.signal(name, parameters: properties)
        #if DEBUG
        print("[Analytics] Sent v2: \(name) \(properties)")
        #endif
    }
}
#elseif canImport(TelemetryClient)
import TelemetryClient

public final class TelemetryDeckAnalyticsService: AnalyticsService {
    private let appID: String?
    private var isConfigured = false

    public init(appID: String?) { self.appID = appID?.trimmingCharacters(in: .whitespacesAndNewlines) }

    public func configure() {
        guard !isConfigured, let appID, !appID.isEmpty else { return }
        var config = TelemetryManagerConfiguration(appID: appID)
        #if DEBUG
        config.testMode = true
        #endif
        TelemetryManager.initialize(with: config)
        #if DEBUG
        print("[Analytics] TelemetryClient v1 configured (testMode=\(config.testMode))")
        #endif
        isConfigured = true
    }

    public func track(_ name: String, properties: [String: String]) {
        guard isConfigured else {
            #if DEBUG
            print("[Analytics] Skipped (not configured): \(name)")
            #endif
            return
        }
        TelemetryManager.send(name, with: properties)
        #if DEBUG
        print("[Analytics] Sent v1: \(name) \(properties)")
        #endif
    }
}
#endif
