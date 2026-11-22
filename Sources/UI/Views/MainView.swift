import SwiftUI

public struct MainView: View {
    @ObservedObject var viewModel: ProxyViewModel = ProxyViewModel.shared
    @Environment(\.colorScheme) var systemColorScheme

    private var isLight: Bool {
        if let mode = viewModel.appearanceMode.colorScheme {
            return mode == .light
        }
        return systemColorScheme == .light
    }

    public var body: some View {
        ZStack {
            // macOS 26 Liquid Glass Vibrancy Background
            VisualEffectBackground(material: .windowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Luminous Frosted Tint for Light Mode (eliminates muddy gray tones)
            if isLight {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.985, blue: 0.995).opacity(0.92),
                        Color(red: 0.95, green: 0.96, blue: 0.975).opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Header Bar (Title, Stats, Mode Switcher, Actions)
                HeaderBarView(viewModel: viewModel)

                // Main Content Body: Visual Mode vs Config Mode
                Group {
                    if viewModel.currentMode == .visual {
                        VisualModeView(viewModel: viewModel)
                    } else {
                        ConfigModeView(viewModel: viewModel)
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
