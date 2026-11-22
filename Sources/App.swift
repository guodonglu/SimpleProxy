import SwiftUI
import AppKit

@main
struct SimpleProxyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ProxyViewModel.shared

    var body: some Scene {
        WindowGroup("SimpleProxy") {
            MainView(viewModel: viewModel)
                .frame(minWidth: 720, minHeight: 460)
                .background(VisualEffectBackground(material: .windowBackground, blendingMode: .behindWindow))
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 860, height: 560)

        // Menu Bar Companion
        MenuBarExtra {
            Text("SimpleProxy 极简代理")
                .font(.headline)

            Divider()

            // 1. 代理服务主开关
            Toggle(viewModel.isServerRunning ? "代理服务：已开启" : "代理服务：已暂停", isOn: Binding(
                get: { viewModel.isServerRunning },
                set: { _ in viewModel.toggleProxy() }
            ))

            Text(viewModel.isServerRunning ? "端口: 127.0.0.1:9898" : "端口: 127.0.0.1:9898 (已暂停)")

            Button(viewModel.isServerRunning ? "暂停代理服务" : "启动代理服务") {
                viewModel.toggleProxy()
            }
            .keyboardShortcut("p", modifiers: .command)

            Divider()

            // 2. 规则快速开关
            if !viewModel.rules.isEmpty {
                Menu("规则快捷开关 (\(viewModel.rules.filter { $0.isEnabled }.count)/\(viewModel.rules.count))") {
                    Button(viewModel.rules.allSatisfy { $0.isEnabled } ? "停用所有规则" : "启用所有规则") {
                        let shouldEnable = !viewModel.rules.allSatisfy { $0.isEnabled }
                        viewModel.toggleAllRules(enable: shouldEnable)
                    }
                    Divider()
                    ForEach(viewModel.rules) { rule in
                        Toggle(rule.pattern.isEmpty ? "未命名规则" : rule.pattern, isOn: Binding(
                            get: { rule.isEnabled },
                            set: { _ in viewModel.toggleRule(id: rule.id) }
                        ))
                    }
                }
                Divider()
            }

            // 3. 窗口与操作
            Button("显示主窗口") {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.canBecomeKey {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("新增规则...") {
                viewModel.editingRule = nil
                viewModel.isShowingRuleSheet = true
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.canBecomeKey {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("退出 SimpleProxy") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: viewModel.isServerRunning ? "arrow.triangle.swap" : "pause.circle")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in menu bar
    }
}
