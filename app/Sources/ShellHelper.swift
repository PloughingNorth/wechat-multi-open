import Foundation
import AppKit

enum ShellError: LocalizedError {
    case executionFailed(String)
    case privilegedFailed(String)

    var errorDescription: String? {
        switch self {
        case .executionFailed(let msg): return "命令执行失败: \(msg)"
        case .privilegedFailed(let msg): return "权限命令失败: \(msg)"
        }
    }
}

struct ShellHelper {

    /// Run a shell command and return its stdout.
    @discardableResult
    static func run(_ command: String) throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 && output.isEmpty == false {
            // Some commands return non-zero but still produce useful output
            // Only throw if there's a real problem
        }

        return output
    }

    /// Run a command with administrator privileges via NSAppleScript.
    /// This shows the system password dialog.
    @discardableResult
    static func runPrivileged(_ command: String) throws -> String {
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        do shell script "\(escapedCommand)" with administrator privileges
        """

        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)

        if let error = error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "未知错误"
            throw ShellError.privilegedFailed(message)
        }

        return result?.stringValue ?? ""
    }

    /// Run a command with administrator privileges, combining multiple commands.
    @discardableResult
    static func runPrivilegedScript(_ commands: [String]) throws -> String {
        let combined = commands.joined(separator: " && ")
        return try runPrivileged(combined)
    }
}
