import SwiftUI

public struct ConfigModeView: View {
    @ObservedObject var viewModel: ProxyViewModel
    @State private var text: String = ""

    public var body: some View {
        VStack(spacing: 0) {
            // Helper Snippet Toolbar
            HStack(spacing: 12) {
                Text("Whistle 语法快捷模版:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WhistTheme.labelSecondary)

                // Quick Insert: Host
                Button("+ Host 映射") {
                    insertSnippet("local.example.com 127.0.0.1:8080 # 示例开发端口")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                // Quick Insert: Mock
                Button("+ Mock 数据") {
                    insertSnippet("api.example.com/mock resBody://({\"code\":0,\"data\":{\"msg\":\"ok\"}})")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                // Quick Insert: Remote
                Button("+ 远程重定向") {
                    insertSnippet("cdn.prod.com https://cdn.dev.com")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                // Quick Insert: Status Code
                Button("+ 状态码") {
                    insertSnippet("error.test.com statusCode://503")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Spacer()

                // Status indication
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(WhistTheme.activeGreen)
                        .font(.system(size: 11))
                    Text("实时生效 (\(viewModel.rules.filter { $0.isEnabled }.count) 条启用)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(WhistTheme.labelSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))

            Divider().opacity(0.4)

            // Monospaced Code Text Editor
            TextEditor(text: Binding(
                get: { viewModel.rawConfigText },
                set: { newText in
                    viewModel.onConfigTextUpdated(newText)
                }
            ))
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .lineSpacing(4)
            .padding(14)
            .scrollContentBackground(.hidden)
            .background(WhistTheme.cardBackground)
        }
    }

    private func insertSnippet(_ snippet: String) {
        var current = viewModel.rawConfigText
        if !current.hasSuffix("\n") && !current.isEmpty {
            current += "\n"
        }
        current += snippet + "\n"
        viewModel.onConfigTextUpdated(current)
    }
}
