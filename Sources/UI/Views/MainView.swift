import SwiftUI

public struct MainView: View {
    @StateObject private var viewModel = ProxyViewModel()

    public var body: some View {
        ZStack {
            // macOS 26 Liquid Glass Vibrancy Background
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar (Title, Stats, Mode Switcher, Actions)
                HeaderBarView(viewModel: viewModel)

                // Main Content Body: Visual Mode vs Config Mode
                ZStack {
                    if viewModel.currentMode == .visual {
                        VisualModeView(viewModel: viewModel)
                            .transition(.opacity)
                    } else {
                        ConfigModeView(viewModel: viewModel)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Background Shortcut Listeners
                Group {
                    Button(action: { viewModel.currentMode = .visual }) { EmptyView() }
                        .keyboardShortcut("1", modifiers: .command)
                    Button(action: { viewModel.currentMode = .config }) { EmptyView() }
                        .keyboardShortcut("2", modifiers: .command)
                }
                .frame(width: 0, height: 0)
                .opacity(0)
            }
        }
        .sheet(isPresented: $viewModel.isShowingRuleSheet) {
            RuleEditSheet(viewModel: viewModel)
        }
        .alert(isPresented: $viewModel.isShowingAlert) {
            Alert(
                title: Text("提示"),
                message: Text(viewModel.alertMessage ?? "发生未知错误"),
                dismissButton: .default(Text("好的"))
            )
        }
        .preferredColorScheme(viewModel.appearanceMode.colorScheme)
    }
}
