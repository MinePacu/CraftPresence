//
//  LogHelper.swift
//  CraftPresence
//
//  Created by Assistant on 2025-11-12.
//

import Foundation
import os.log
import SwiftUI

/// Centralized lightweight logging helper that respects the debug toggle in Settings.
/// - Behavior:
///   - Only logs in DEBUG builds.
///   - Respects `@AppStorage("debugLoggingEnabled")` so users can toggle logs in Settings.
///   - Supports both `print` and `os.Logger` backends.
public enum Log {
    /// Shared OS logger for the app. Customize subsystem/category as needed.
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CraftPresence", category: "App")

    /// Reads the debug toggle from AppStorage using `UserDefaults.standard` bridge.
    /// We avoid requiring SwiftUI contexts at call sites by reading the raw defaults value.
    private static var isEnabled: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "debugLoggingEnabled")
        #else
        return false
        #endif
    }

    /// Log a message with optional category using print.
    /// - Parameters:
    ///   - message: The message to log. Use string interpolation lazily.
    ///   - category: Optional category tag.
    public static func d(_ message: @autoclosure () -> String, category: String? = nil, file: String = #fileID, function: String = #function, line: Int = #line) {
        #if DEBUG
        guard isEnabled else { return }
        let tag = category.map { "[\($0)] " } ?? ""
        let prefix = "[DEBUG] \(tag)\(file):\(line) \(function) — "
        print(prefix + message())
        #endif
    }

    /// Log a message using os.Logger (visible in Console.app).
    public static func os(_ message: @autoclosure () -> String, level: OSLogType = .debug, category: String? = nil, file: String = #fileID, function: String = #function, line: Int = #line) {
        #if DEBUG
        guard isEnabled else { return }
        let tag = category.map { "[\($0)] " } ?? ""
        let msg = message()
        switch level {
        case .debug:
            logger.debug("\(tag)\(file):\(line) \(function) — \(msg)")
        case .info:
            logger.info("\(tag)\(file):\(line) \(function) — \(msg)")
        case .error:
            logger.error("\(tag)\(file):\(line) \(function) — \(msg)")
        case .fault:
            logger.fault("\(tag)\(file):\(line) \(function) — \(msg)")
        default:
            logger.log("\(tag)\(file):\(line) \(function) — \(msg)")
        }
        #endif
    }
}

