//  ScriptRunner.swift
//  CraftPresence
//
//  Utility to execute AppleScript from Swift on macOS.
//  Provides two strategies:
//  1) NSAppleScript: compile & run in-process, returning NSAppleEventDescriptor
//  2) osascript: invoke /usr/bin/osascript via Process, returning stdout/stderr
//
//  Note: AppleScript automation requires user consent (TCC) when targeting other apps.
//  For sandboxed apps, ensure the proper entitlement (com.apple.security.automation.apple-events)
//  and consider NSUserAppleScriptTask for running user-provided scripts.
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif

public enum AppleScriptRunError: Error, LocalizedError, Equatable {
    case compileOrRunError(details: [String: Any])
    case processFailed(exitCode: Int32, stderr: String)
    case scriptNotFound(URL)
    case unsupportedPlatform

    public var errorDescription: String? {
        switch self {
        case .compileOrRunError(let details):
            return "AppleScript execution failed: \(details)"
        case .processFailed(let code, let stderr):
            return "osascript failed (code: \(code)): \(stderr)"
        case .scriptNotFound(let url):
            return "AppleScript file not found at: \(url.path)"
        case .unsupportedPlatform:
            return "AppleScript is only available on macOS."
        }
    }
}

extension AppleScriptRunError {
    public static func == (lhs: AppleScriptRunError, rhs: AppleScriptRunError) -> Bool {
        switch (lhs, rhs) {
        case (.unsupportedPlatform, .unsupportedPlatform):
            return true
        case (.scriptNotFound(let lURL), .scriptNotFound(let rURL)):
            return lURL == rURL
        case (.processFailed(let lCode, let lErr), .processFailed(let rCode, let rErr)):
            return lCode == rCode && lErr == rErr
        case (.compileOrRunError(let lDetails), .compileOrRunError(let rDetails)):
            // Compare keys and stringified values to avoid non-Equatable Any
            guard lDetails.count == rDetails.count else { return false }
            for (key, lValue) in lDetails {
                guard let rValue = rDetails[key] else { return false }
                // Use String(describing:) for a best-effort comparison of values
                if String(describing: lValue) != String(describing: rValue) { return false }
            }
            return true
        default:
            return false
        }
    }
}

public struct ScriptRunner {
    public var logEnabled: Bool
    public var logHandler: ((String) -> Void)?

    public init(logEnabled: Bool = false, logHandler: ((String) -> Void)? = nil) {
        self.logEnabled = logEnabled
        self.logHandler = logHandler
    }

    private func log(_ message: String) {
        guard logEnabled else { return }
        if let handler = logHandler { handler(message) } else { print(message) }
    }

    // MARK: - NSAppleScript (in-process)

    /// Execute AppleScript source using NSAppleScript and return the result descriptor.
    /// - Parameter source: AppleScript source code as String
    /// - Returns: Optional NSAppleEventDescriptor result
    @discardableResult
    public func runAppleScriptSource(_ source: String) throws -> NSAppleEventDescriptor? {
        #if os(macOS)
        var errorDict: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&errorDict)
        if let error = errorDict as? [String: Any], !error.isEmpty {
            log("AppleScript(NSAppleScript) error: \(error)")
            throw AppleScriptRunError.compileOrRunError(details: error)
        }
        let resultString: String
        if let s = result?.stringValue {
            resultString = s
        } else if let r = result {
            resultString = r.description
        } else {
            resultString = "<nil>"
        }
        log("AppleScript(NSAppleScript) result: \(resultString)")
        return result
        #else
        throw AppleScriptRunError.unsupportedPlatform
        #endif
    }

    /// Execute a .scpt or .applescript file via NSAppleScript.
    /// - Parameter fileURL: URL to the script file
    /// - Returns: Optional NSAppleEventDescriptor result
    @discardableResult
    public func runAppleScriptFile(_ fileURL: URL) throws -> NSAppleEventDescriptor? {
        #if os(macOS)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AppleScriptRunError.scriptNotFound(fileURL)
        }
        log("Running AppleScript file: \(fileURL.path)")
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        let result = try runAppleScriptSource(source)
        let resultString: String
        if let s = result?.stringValue {
            resultString = s
        } else if let r = result {
            resultString = r.description
        } else {
            resultString = "<nil>"
        }
        log("AppleScript(NSAppleScript) file result: \(resultString)")
        return result
        #else
        throw AppleScriptRunError.unsupportedPlatform
        #endif
    }

    // MARK: - osascript (Process-based)

    /// Execute AppleScript using /usr/bin/osascript with multiple -e lines.
    /// - Parameter lines: Each element will be passed as a separate -e argument to osascript.
    /// - Returns: Standard output string (trimmed). Throws on non-zero exit with stderr.
    public func runWithOsascript(lines: [String]) throws -> String {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = lines.flatMap { ["-e", $0] }

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        try process.run()
        process.waitUntilExit()

        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let stdoutStr = String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        log("osascript stdout: \(stdoutStr)")

        if process.terminationStatus != 0 {
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            let stderrStr = String(decoding: errData, as: UTF8.self)
            log("osascript error (code: \(process.terminationStatus)): \(stderrStr)")
            throw AppleScriptRunError.processFailed(exitCode: process.terminationStatus, stderr: stderrStr)
        }
        return stdoutStr
        #else
        throw AppleScriptRunError.unsupportedPlatform
        #endif
    }

    /// Execute a script file via osascript.
    /// - Parameter fileURL: URL to .scpt or .applescript file
    /// - Returns: Standard output string (trimmed)
    public func runWithOsascript(fileURL: URL) throws -> String {
        #if os(macOS)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AppleScriptRunError.scriptNotFound(fileURL)
        }

        log("Running osascript file: \(fileURL.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [fileURL.path]

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        try process.run()
        process.waitUntilExit()

        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let stdoutStr = String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        log("osascript stdout: \(stdoutStr)")

        if process.terminationStatus != 0 {
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            let stderrStr = String(decoding: errData, as: UTF8.self)
            log("osascript error (code: \(process.terminationStatus)): \(stderrStr)")
            throw AppleScriptRunError.processFailed(exitCode: process.terminationStatus, stderr: stderrStr)
        }
        return stdoutStr
        #else
        throw AppleScriptRunError.unsupportedPlatform
        #endif
    }
    
    // MARK: - Streaming osascript support

    private func _consumeLines(from data: Data, buffer: inout Data, emit: (String) -> Void) {
        buffer.append(data)
        while true {
            if let range = buffer.firstRange(of: Data([0x0A])) { // \n
                let lineData = buffer.subdata(in: 0..<range.startIndex)
                // Drop the line including the newline
                buffer.removeSubrange(0..<(range.endIndex))
                var line = String(decoding: lineData, as: UTF8.self)
                if line.hasSuffix("\r") { line.removeLast() }
                emit(line)
            } else {
                break
            }
        }
    }

    /// Stream osascript output line-by-line for a given script file.
    /// - Parameters:
    ///   - fileURL: URL to .scpt or .applescript file
    ///   - arguments: Additional arguments passed to osascript after the file path (e.g., ["watch", "0.5", "20"]).
    ///   - onLine: Called for each stdout line
    ///   - onErrorLine: Called for each stderr line (optional)
    ///   - onComplete: Called when process terminates with exit code or error
    /// - Returns: The running Process instance (so caller can terminate if needed)
    @discardableResult
    public func streamWithOsascript(
        fileURL: URL,
        arguments: [String] = [],
        onLine: @escaping (String) -> Void,
        onErrorLine: ((String) -> Void)? = nil,
        onComplete: @escaping (Result<Int32, AppleScriptRunError>) -> Void
    ) throws -> Process {
        #if os(macOS)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AppleScriptRunError.scriptNotFound(fileURL)
        }

        log("Streaming osascript file: \(fileURL.path) args: \(arguments)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [fileURL.path] + arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var outBuffer = Data()
        var errBuffer = Data()
        var fullErr = Data()

        let outHandle = stdoutPipe.fileHandleForReading
        let errHandle = stderrPipe.fileHandleForReading

        outHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                self._consumeLines(from: data, buffer: &outBuffer) { line in
                    self.log("osascript (stdout): \(line)")
                    onLine(line)
                }
            }
        }

        errHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                fullErr.append(data)
                self._consumeLines(from: data, buffer: &errBuffer) { line in
                    self.log("osascript (stderr): \(line)")
                    onErrorLine?(line)
                }
            }
        }

        process.terminationHandler = { proc in
            // Flush any remaining partial lines
            if outBuffer.count > 0 {
                let line = String(decoding: outBuffer, as: UTF8.self)
                if !line.isEmpty {
                    self.log("osascript (stdout): \(line)")
                    onLine(line)
                }
            }
            if errBuffer.count > 0 {
                let line = String(decoding: errBuffer, as: UTF8.self)
                if !line.isEmpty {
                    self.log("osascript (stderr): \(line)")
                    onErrorLine?(line)
                }
            }

            outHandle.readabilityHandler = nil
            errHandle.readabilityHandler = nil

            let code = proc.terminationStatus
            if code == 0 {
                onComplete(.success(code))
            } else {
                let stderrStr = String(decoding: fullErr, as: UTF8.self)
                self.log("osascript error (code: \(code)): \(stderrStr)")
                onComplete(.failure(.processFailed(exitCode: code, stderr: stderrStr)))
            }
        }

        try process.run()
        return process
        #else
        throw AppleScriptRunError.unsupportedPlatform
        #endif
    }

    /// Stream osascript output line-by-line for inline script lines (-e ...).
    /// - Parameters:
    ///   - lines: Each element is passed as a separate -e argument to osascript
    ///   - onLine: Called for each stdout line
    ///   - onErrorLine: Called for each stderr line (optional)
    ///   - onComplete: Called when process terminates with exit code or error
    /// - Returns: The running Process instance (so caller can terminate if needed)
    @discardableResult
    public func streamWithOsascript(
        lines: [String],
        onLine: @escaping (String) -> Void,
        onErrorLine: ((String) -> Void)? = nil,
        onComplete: @escaping (Result<Int32, AppleScriptRunError>) -> Void
    ) throws -> Process {
        #if os(macOS)
        log("Streaming osascript lines: \(lines.count) line(s)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = lines.flatMap { ["-e", $0] }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var outBuffer = Data()
        var errBuffer = Data()
        var fullErr = Data()

        let outHandle = stdoutPipe.fileHandleForReading
        let errHandle = stderrPipe.fileHandleForReading

        outHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                self._consumeLines(from: data, buffer: &outBuffer) { line in
                    self.log("osascript (stdout): \(line)")
                    onLine(line)
                }
            }
        }

        errHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                fullErr.append(data)
                self._consumeLines(from: data, buffer: &errBuffer) { line in
                    self.log("osascript (stderr): \(line)")
                    onErrorLine?(line)
                }
            }
        }

        process.terminationHandler = { proc in
            if outBuffer.count > 0 {
                let line = String(decoding: outBuffer, as: UTF8.self)
                if !line.isEmpty {
                    self.log("osascript (stdout): \(line)")
                    onLine(line)
                }
            }
            if errBuffer.count > 0 {
                let line = String(decoding: errBuffer, as: UTF8.self)
                if !line.isEmpty {
                    self.log("osascript (stderr): \(line)")
                    onErrorLine?(line)
                }
            }

            outHandle.readabilityHandler = nil
            errHandle.readabilityHandler = nil

            let code = proc.terminationStatus
            if code == 0 {
                onComplete(.success(code))
            } else {
                let stderrStr = String(decoding: fullErr, as: UTF8.self)
                self.log("osascript error (code: \(code)): \(stderrStr)")
                onComplete(.failure(.processFailed(exitCode: code, stderr: stderrStr)))
            }
        }

        try process.run()
        return process
        #else
        throw AppleScriptRunError.unsupportedPlatform
        #endif
    }
}

// MARK: - Async/Await convenience
public extension ScriptRunner {
    @discardableResult
    func runAppleScriptSource(_ source: String) async throws -> NSAppleEventDescriptor? {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do { cont.resume(returning: try self.runAppleScriptSource(source)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    @discardableResult
    func runAppleScriptFile(_ fileURL: URL) async throws -> NSAppleEventDescriptor? {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do { cont.resume(returning: try self.runAppleScriptFile(fileURL)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    func runWithOsascript(lines: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do { cont.resume(returning: try self.runWithOsascript(lines: lines)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    func runWithOsascript(fileURL: URL) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do { cont.resume(returning: try self.runWithOsascript(fileURL: fileURL)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }
}
