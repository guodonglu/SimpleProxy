import SwiftUI

public struct HeaderBarView: View {
    @ObservedObject var viewModel: ProxyViewModel
    @Environment(\.colorScheme) var colorScheme

    public var body: some View {
        HStack(spacing: 16) {
            // Left: Traffic Light safety margin + Status indicator
            HStack(spacing: 8) {
                // Running status & port badge
                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.isServerRunning ? ProxyTheme.activeGreen : ProxyTheme.labelTertiary)
                        .frame(width: 6, height: 6)
                    Text(viewModel.isServerRunning ? "端口 \(String(viewModel.serverPort))" : "已停止")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(viewModel.isServerRunning ? ProxyTheme.activeGreen : ProxyTheme.labelTertiary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(viewModel.isServerRunning ? ProxyTheme.activeGreen.opacity(0.12) : Color.primary.opacity(0.06))
                )

                Text("\(viewModel.rules.count) 条规则")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ProxyTheme.labelSecondary)
            }
            .padding(.leading, ProxyTheme.trafficLightsMargin)

            Spacer()

            // Center: Dual Mode Switcher Segmented Control
            Picker("", selection: $viewModel.currentMode) {
                ForEach(AppMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)

            Spacer()

            // Right: Action Buttons (Add, Import, Export, Power)
            HStack(spacing: 8) {
                // Add Rule Button
                Button {
                    viewModel.editingRule = nil
                    viewModel.isShowingRuleSheet = true
                } label: {
                    Label("新增规则", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(ProxyTheme.accent)
                .controlSize(.regular)
                .keyboardShortcut("n", modifiers: .command)

                // Import
                Button {
                    viewModel.importConfiguration()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help("导入规则文件 (⌘O)")
                .keyboardShortcut("o", modifiers: .command)

                // Export
                Button {
                    viewModel.exportConfiguration()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .help("导出规则文件 (⌘S)")
                .keyboardShortcut("s", modifiers: .command)

                // Appearance Toggle (Auto / Light / Dark)
                Button {
                    viewModel.cycleAppearance()
                } label: {
                    Image(systemName: viewModel.appearanceMode.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ProxyTheme.labelSecondary)
                }
                .buttonStyle(.plain)
                .help("切换外观模式: 当前为 \(viewModel.appearanceMode.rawValue)")
                .padding(.horizontal, 4)

                // Power Toggle
                Button {
                    viewModel.toggleProxy()
                } label: {
                    Image(systemName: viewModel.isServerRunning ? "power.circle.fill" : "power.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(viewModel.isServerRunning ? ProxyTheme.activeGreen : ProxyTheme.labelTertiary)
                }
                .buttonStyle(.plain)
                .help(viewModel.isServerRunning ? "停止代理服务" : "启动代理服务")
                .padding(.horizontal, 4)
            }
            .padding(.trailing, 16)
        }
        .frame(height: 52)
        .background(
            colorScheme == .light
                ? Color.white.opacity(0.85)
                : Color.black.opacity(0.20)
        )
        .overlay(
            Divider().opacity(colorScheme == .light ? 0.25 : 0.4),
            alignment: .bottom
        )
    }
}
