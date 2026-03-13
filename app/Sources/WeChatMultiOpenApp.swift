import SwiftUI

@main
struct WeChatMultiOpenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 560, height: 450)
    }
}
