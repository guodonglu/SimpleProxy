import SwiftUI
import AppKit

@main
struct WhistFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 720, minHeight: 460)
                .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 860, height: 560)

        // Menu Bar Companion
        MenuBarExtra("WhistFlow", systemImage: "waveform.path.ecg") {
            Text("WhistFlow 极简代理")
                .font(.headline)
            Divider()
            Text("端口: 127.0.0.1:9898")
            Divider()
            Button("显示主窗口") {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            Divider()
            Button("退出 WhistFlow") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in menu bar
    }
}
