import SwiftUI

public struct HeaderBarView: View {
    @ObservedObject var viewModel: ProxyViewModel

    public var body: some View {
        HStack(spacing: 16) {
            // Left: Traffic Light safety margin + Branding
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(WhistTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(WhistTheme.accentSubtle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("WhistFlow")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(WhistTheme.labelPrimary)

                        // Running status badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.isServerRunning ? WhistTheme.activeGreen : WhistTheme.labelTertiary)
                                .frame(width: 6, height: 6)
                            Text(viewModel.isServerRunning ? ":\(String(viewModel.serverPort))" : "已停止")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(viewModel.isServerRunning ? WhistTheme.activeGreen : WhistTheme.labelTertiary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(viewModel.isServerRunning ? WhistTheme.activeGreen.opacity(0.12) : Color.primary.opacity(0.05))
                        )
                    }

                    HStack(spacing: 8) {
                        Text("\(viewModel.rules.count) 条规则")
                        Text("•")
                        Text("内存 \(String(format: "%.1f", viewModel.memoryUsageMB)) MB")
                        Text("•")
                        Text("\(viewModel.matchedRequests) 命中")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(WhistTheme.labelSecondary)
                }
            }
            .padding(.leading, WhistTheme.trafficLightsMargin)

            Spacer()

            // Center: Dual Mode Switcher Segmented Control
            Picker("视图模式", selection: $viewModel.currentMode) {
                ForEach(AppMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 230)

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
                .tint(WhistTheme.accent)
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
                .help("导入 Whistle 规则 (⌘O)")
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

                // Power Toggle
                Button {
                    viewModel.toggleProxy()
                } label: {
                    Image(systemName: viewModel.isServerRunning ? "power.circle.fill" : "power.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(viewModel.isServerRunning ? WhistTheme.activeGreen : WhistTheme.labelTertiary)
                }
                .buttonStyle(.plain)
                .help(viewModel.isServerRunning ? "停止代理服务" : "启动代理服务")
                .padding(.horizontal, 4)
            }
            .padding(.trailing, 16)
        }
        .frame(height: 52)
        .background(.ultraThinMaterial)
        .overlay(
            Divider().opacity(0.5),
            alignment: .bottom
        )
    }
}
