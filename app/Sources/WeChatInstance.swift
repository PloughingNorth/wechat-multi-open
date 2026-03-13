import Foundation

struct WeChatInstance: Identifiable {
    let id: String
    let name: String
    let path: String
    var version: String
    let isOriginal: Bool
    var isRunning: Bool
    var needsUpdate: Bool

    /// The copy number (e.g. 2 for WeChat2.app), nil for original
    var copyNumber: Int? {
        if isOriginal { return nil }
        let digits = name.replacingOccurrences(of: "WeChat", with: "")
                        .replacingOccurrences(of: ".app", with: "")
        return Int(digits)
    }

    var statusText: String {
        if isOriginal { return "原版" }
        return needsUpdate ? "需更新" : "已最新"
    }
}
