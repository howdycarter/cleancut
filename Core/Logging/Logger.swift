//
//  Logger.swift
//

import Foundation

public enum LogLevel: String { case debug, info, warning, error }

public struct AppLogger {
    public static func log(_ message: String, level: LogLevel = .info, file: StaticString = #file, line: UInt = #line) {
        #if DEBUG
        let fileName = ("\(file)" as NSString).lastPathComponent
        print("[\(level.rawValue.uppercased())] \(fileName):\(line) - \(message)")
        #endif
    }
}

