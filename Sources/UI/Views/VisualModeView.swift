import SwiftUI

public struct VisualModeView: View {
    @ObservedObject var viewModel: ProxyViewModel

    public var body: some View {
        VStack(spacing: 0) {
            // Sub-toolbar: Category Filters & Search Bar
            HStack(spacing: 12) {
                // Category Pills
                HStack(spacing: 6) {
                    ForEach(RuleFilterType.allCases) { filter in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.filterType = filter
                            }
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 11, weight: viewModel.filterType == filter ? .semibold : .regular))
                                .foregroundColor(viewModel.filterType == filter ? WhistTheme.accent : WhistTheme.labelSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(viewModel.filterType == filter ? WhistTheme.accentSubtle : WhistTheme.pillBackground)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(filter.rawValue)
                    }
                }

                Spacer()

                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(WhistTheme.labelTertiary)
                    TextField("搜索域名、路径或目标...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .frame(width: 180)
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(WhistTheme.labelTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清空搜索")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(WhistTheme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(WhistTheme.cardBorder, lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))

            Divider().opacity(0.4)

            // Content Area: Rules List or Empty State
            if filteredIndices.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "slider.horizontal.2.square")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(WhistTheme.labelTertiary)
                    Text(viewModel.rules.isEmpty ? "暂无代理规则" : "没有符合筛选条件的规则")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(WhistTheme.labelSecondary)
                    Text("点击上方「新增规则」或切换至「配置代码模式」直接编写")
                        .font(.system(size: 12))
                        .foregroundColor(WhistTheme.labelTertiary)
                    Button {
                        viewModel.editingRule = nil
                        viewModel.isShowingRuleSheet = true
                    } label: {
                        Label("立即新建规则", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredIndices, id: \.self) { idx in
                            RuleCardRow(rule: $viewModel.rules[idx], viewModel: viewModel)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var filteredIndices: [Int] {
        viewModel.rules.indices.filter { idx in
            let rule = viewModel.rules[idx]
            let matchesCategory: Bool
            switch viewModel.filterType {
            case .all: matchesCategory = true
            case .host:
                if case .hostRedirect = rule.action { matchesCategory = true } else { matchesCategory = false }
            case .mock:
                if case .mapLocal = rule.action { matchesCategory = true } else { matchesCategory = false }
            case .remote:
                if case .mapRemote = rule.action { matchesCategory = true } else { matchesCategory = false }
            case .header:
                if case .reqHeaders = rule.action { matchesCategory = true } else { matchesCategory = false }
            }
            guard matchesCategory else { return false }

            if viewModel.searchText.isEmpty { return true }
            let query = viewModel.searchText.lowercased()
            return rule.pattern.lowercased().contains(query) ||
                   rule.action.displayTarget.lowercased().contains(query) ||
                   (rule.comment?.lowercased().contains(query) ?? false)
        }
    }
}

// MARK: - Custom Native Mac Toggle Component
public struct MacToggle: View {
    public var isOn: Bool
    public var onToggle: () -> Void

    public init(isOn: Bool, onToggle: @escaping () -> Void) {
        self.isOn = isOn
        self.onToggle = onToggle
    }

    public var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                onToggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(isOn ? WhistTheme.accent : Color.primary.opacity(0.18))
                    .frame(width: 34, height: 20)

                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .padding(.horizontal, 2)
                    .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 1)
            }
            .frame(width: 34, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Individual Rule Card Component
struct RuleCardRow: View {
    @Binding var rule: ProxyRule
    @ObservedObject var viewModel: ProxyViewModel
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            // 1. Instant Real-time Toggle Switch with Crystal Clear Visual State
            MacToggle(isOn: rule.isEnabled) {
                rule.isEnabled.toggle()
                viewModel.onRuleMutated()
            }
            .help(rule.isEnabled ? "规则已生效，点击禁用" : "规则已停用，点击启用")

            // 2. Action Type Badge
            Text(rule.action.typeName)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(rule.action.badgeColor.opacity(rule.isEnabled ? 0.9 : 0.4))
                )

            // 3. Pattern / Source Domain
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(rule.pattern)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(rule.isEnabled ? WhistTheme.labelPrimary : WhistTheme.labelTertiary)
                        .strikethrough(!rule.isEnabled)

                    if let comment = rule.comment, !comment.isEmpty {
                        Text("// \(comment)")
                            .font(.system(size: 11))
                            .foregroundColor(WhistTheme.labelTertiary)
                    }
                }

                // Target Action Details
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundColor(WhistTheme.labelTertiary)
                    Text(rule.action.displayTarget)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(rule.isEnabled ? WhistTheme.labelSecondary : WhistTheme.labelTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 4. Hover Action Buttons (Edit, Duplicate, Delete)
            HStack(spacing: 6) {
                // Edit
                Button {
                    viewModel.editingRule = rule
                    viewModel.isShowingRuleSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(WhistTheme.labelSecondary)
                .help("编辑规则")

                // Duplicate
                Button {
                    viewModel.duplicateRule(rule: rule)
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(WhistTheme.labelSecondary)
                .help("复制此规则")

                // Delete
                Button {
                    viewModel.deleteRule(id: rule.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(WhistTheme.errorRed.opacity(0.8))
                .help("删除此规则")
            }
            .opacity(isHovered ? 1.0 : 0.4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 10, isHighlighted: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
