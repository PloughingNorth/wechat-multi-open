import Foundation
import SwiftUI

@MainActor
class WeChatManager: ObservableObject {

    static let applicationsPath = "/Applications"
    static let originalPath = "/Applications/WeChat.app"
    static let baseBundleID = "com.tencent.xinWeChat"
    static let iconBackupDir = "/tmp/wechat-multi-open-icons-backup"

    @Published var instances: [WeChatInstance] = []
    @Published var isLoading = false
    @Published var progressMessage = ""
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Scan

    func scan() {
        isLoading = true
        progressMessage = "正在扫描微信实例..."

        var results: [WeChatInstance] = []
        let originalVersion = getVersion(at: Self.originalPath)
        let runningApps = NSWorkspace.shared.runningApplications.map { $0.bundleIdentifier ?? "" }

        // Original
        if FileManager.default.fileExists(atPath: Self.originalPath) {
            let isRunning = runningApps.contains(Self.baseBundleID)
            results.append(WeChatInstance(
                id: "original",
                name: "WeChat.app",
                path: Self.originalPath,
                version: originalVersion,
                isOriginal: true,
                isRunning: isRunning,
                needsUpdate: false
            ))
        }

        // Copies: WeChat2.app ... WeChat99.app
        for i in 2...99 {
            let path = "\(Self.applicationsPath)/WeChat\(i).app"
            guard FileManager.default.fileExists(atPath: path) else { continue }

            let version = getVersion(at: path)
            let bundleID = "\(Self.baseBundleID)\(i)"
            let isRunning = runningApps.contains(bundleID)
            let needsUpdate = version != originalVersion

            results.append(WeChatInstance(
                id: "copy-\(i)",
                name: "WeChat\(i).app",
                path: path,
                version: version,
                isOriginal: false,
                isRunning: isRunning,
                needsUpdate: needsUpdate
            ))
        }

        instances = results
        isLoading = false
        progressMessage = ""
    }

    // MARK: - Get Version

    func getVersion(at appPath: String) -> String {
        let plistPath = "\(appPath)/Contents/Info.plist"
        guard let output = try? ShellHelper.run(
            "/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' '\(plistPath)'"
        ), !output.isEmpty else {
            return "未知"
        }
        return output
    }

    // MARK: - Create Copy

    func createCopy() async {
        isLoading = true

        // Find next available number
        var nextNum = 2
        while FileManager.default.fileExists(atPath: "\(Self.applicationsPath)/WeChat\(nextNum).app") {
            nextNum += 1
        }

        let dst = "\(Self.applicationsPath)/WeChat\(nextNum).app"
        let bundleID = "\(Self.baseBundleID)\(nextNum)"

        progressMessage = "正在创建 WeChat\(nextNum).app..."

        do {
            let commands = [
                "cp -R '\(Self.originalPath)' '\(dst)'",
                "/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier \(bundleID)' '\(dst)/Contents/Info.plist'",
                "/usr/libexec/PlistBuddy -c 'Set :CFBundleName WeChat\(nextNum)' '\(dst)/Contents/Info.plist' 2>/dev/null || true",
                "/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName WeChat\(nextNum)' '\(dst)/Contents/Info.plist' 2>/dev/null || true",
                "xattr -cr '\(dst)' 2>/dev/null || true",
                "codesign --force --deep --sign - '\(dst)' 2>/dev/null || true",
                "chown -R $(whoami) '\(dst)'"
            ]
            try ShellHelper.runPrivilegedScript(commands)
            scan()
        } catch {
            showError(error.localizedDescription)
        }

        isLoading = false
        progressMessage = ""
    }

    // MARK: - Update All Copies

    func updateAllCopies() async {
        let copies = instances.filter { !$0.isOriginal }
        guard !copies.isEmpty else {
            showError("没有可更新的副本")
            return
        }

        isLoading = true

        do {
            // Create icon backup directory
            _ = try? ShellHelper.run("mkdir -p '\(Self.iconBackupDir)'")

            for copy in copies {
                guard let num = copy.copyNumber else { continue }
                progressMessage = "正在更新 WeChat\(num).app..."

                let dst = copy.path
                let bundleID = "\(Self.baseBundleID)\(num)"

                // Backup custom icon if different from original
                let hasCustomIcon = backupIcon(num: num)

                // Stop the process
                _ = try? ShellHelper.run("killall 'WeChat\(num)' 2>/dev/null || true")

                // Build the update commands
                var commands = [
                    "rm -rf '\(dst)'",
                    "cp -R '\(Self.originalPath)' '\(dst)'",
                    "/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier \(bundleID)' '\(dst)/Contents/Info.plist'",
                    "/usr/libexec/PlistBuddy -c 'Set :CFBundleName WeChat\(num)' '\(dst)/Contents/Info.plist' 2>/dev/null || true",
                    "/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName WeChat\(num)' '\(dst)/Contents/Info.plist' 2>/dev/null || true"
                ]

                // Restore custom icon
                if hasCustomIcon {
                    let backupPath = "\(Self.iconBackupDir)/WeChat\(num).icns"
                    commands.append("cp '\(backupPath)' '\(dst)/Contents/Resources/AppIcon.icns'")
                    commands.append("touch '\(dst)'")
                }

                commands.append(contentsOf: [
                    "xattr -cr '\(dst)' 2>/dev/null || true",
                    "codesign --force --deep --sign - '\(dst)' 2>/dev/null || true",
                    "chown -R $(whoami) '\(dst)'"
                ])

                try ShellHelper.runPrivilegedScript(commands)
            }

            // Cleanup icon backup
            _ = try? ShellHelper.run("rm -rf '\(Self.iconBackupDir)'")

            // Refresh icon cache
            progressMessage = "正在刷新系统缓存..."
            _ = try? ShellHelper.runPrivileged(
                "rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true; " +
                "find /private/var/folders/ -name com.apple.iconservices -exec rm -rf {} \\; 2>/dev/null || true"
            )
            _ = try? ShellHelper.run("killall Dock 2>/dev/null || true")

            scan()
        } catch {
            showError(error.localizedDescription)
        }

        isLoading = false
        progressMessage = ""
    }

    // MARK: - Delete Copy

    func deleteCopy(_ instance: WeChatInstance) async {
        guard !instance.isOriginal, let num = instance.copyNumber else { return }

        isLoading = true
        progressMessage = "正在删除 WeChat\(num).app..."

        do {
            // Stop process first
            _ = try? ShellHelper.run("killall 'WeChat\(num)' 2>/dev/null || true")

            try ShellHelper.runPrivileged("rm -rf '\(instance.path)'")
            scan()
        } catch {
            showError(error.localizedDescription)
        }

        isLoading = false
        progressMessage = ""
    }

    // MARK: - Launch / Stop

    func launchInstance(_ instance: WeChatInstance) {
        let url = URL(fileURLWithPath: instance.path)
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
        // Delay refresh to let the app start
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.scan()
        }
    }

    func stopInstance(_ instance: WeChatInstance) {
        let bundleID: String
        if instance.isOriginal {
            bundleID = Self.baseBundleID
        } else if let num = instance.copyNumber {
            bundleID = "\(Self.baseBundleID)\(num)"
        } else {
            return
        }

        for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == bundleID {
            app.terminate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.scan()
        }
    }

    // MARK: - Icon Backup

    private func backupIcon(num: Int) -> Bool {
        let srcIcon = "\(Self.originalPath)/Contents/Resources/AppIcon.icns"
        let copyIcon = "\(Self.applicationsPath)/WeChat\(num).app/Contents/Resources/AppIcon.icns"
        let backupPath = "\(Self.iconBackupDir)/WeChat\(num).icns"

        // Compare icons – if different, the user has customized it
        if let result = try? ShellHelper.run("cmp -s '\(srcIcon)' '\(copyIcon)'; echo $?"),
           result == "1" {
            let _ = try? ShellHelper.run("cp '\(copyIcon)' '\(backupPath)'")
            return true
        }
        return false
    }

    // MARK: - Helpers

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
