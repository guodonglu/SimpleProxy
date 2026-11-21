import SwiftUI

public struct RuleEditSheet: View {
    @ObservedObject var viewModel: ProxyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var ruleId: UUID = UUID()
    @State private var isEnabled: Bool = true
    @State private var pattern: String = ""
    @State private var comment: String = ""
    @State private var ruleTypeIndex: Int = 0

    // Host redirect fields
    @State private var targetHost: String = "127.0.0.1"
    @State private var targetPort: String = "8080"

    // Mock fields
    @State private var mockBody: String = "{\"code\": 0, \"message\": \"success\"}"
    @State private var mockStatusCode: String = "200"

    // Remote fields
    @State private var remoteUrl: String = "https://dev-api.internal.com"

    // Status code fields
    @State private var statusCode: String = "503"

    let typeTitles = ["HOST 映射", "MOCK 模拟", "远程重定向", "状态码"]

    public var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack {
                Text(viewModel.editingRule == nil ? "新增代理规则" : "编辑代理规则")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ProxyTheme.labelPrimary)
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(ProxyTheme.labelSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider().opacity(0.4)

            // Form
            Form {
                Section {
                    Picker("规则类型", selection: $ruleTypeIndex) {
                        ForEach(0..<typeTitles.count, id: \.self) { idx in
                            Text(typeTitles[idx]).tag(idx)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 6)

                    TextField("匹配域名或路径 (Pattern):", text: $pattern, prompt: Text("例如: api.example.com 或 /user/*"))
                        .font(.system(.body, design: .monospaced))

                    TextField("备注说明 (可选):", text: $comment, prompt: Text("例如: 本地微服务调试"))
                }

                Section("动作配置") {
                    if ruleTypeIndex == 0 {
                        // Host
                        HStack {
                            TextField("目标主机 IP/域名", text: $targetHost)
                                .font(.system(.body, design: .monospaced))
                            Text(":")
                            TextField("端口", text: $targetPort)
                                .frame(width: 80)
                                .font(.system(.body, design: .monospaced))
                        }
                    } else if ruleTypeIndex == 1 {
                        // Mock
                        TextField("HTTP 状态码", text: $mockStatusCode)
                            .frame(width: 100)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("返回 Body (JSON 或纯文本):")
                                .font(.system(size: 11))
                                .foregroundColor(ProxyTheme.labelSecondary)
                            TextEditor(text: $mockBody)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(height: 90)
                                .border(ProxyTheme.cardBorder, width: 0.5)
                        }
                    } else if ruleTypeIndex == 2 {
                        // Remote
                        TextField("重定向目标完整 URL", text: $remoteUrl)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        // Status code
                        TextField("响应状态码", text: $statusCode)
                            .frame(width: 100)
                    }
                }

                Section {
                    Toggle("保存后立即启用此规则", isOn: $isEnabled)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)

            Divider().opacity(0.4)

            // Sheet Footer
            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存并应用") {
                    saveAction()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(ProxyTheme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(pattern.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 480, height: 460)
        .background(.ultraThinMaterial)
        .onAppear {
            loadExistingRule()
        }
    }

    private func loadExistingRule() {
        if let existing = viewModel.editingRule {
            self.ruleId = existing.id
            self.isEnabled = existing.isEnabled
            self.pattern = existing.pattern
            self.comment = existing.comment ?? ""

            switch existing.action {
            case .hostRedirect(let host, let port):
                self.ruleTypeIndex = 0
                self.targetHost = host
                self.targetPort = "\(port)"
            case .mapLocal(let body, _, let status):
                self.ruleTypeIndex = 1
                self.mockBody = body
                self.mockStatusCode = "\(status)"
            case .mapRemote(let url):
                self.ruleTypeIndex = 2
                self.remoteUrl = url
            case .statusCode(let code):
                self.ruleTypeIndex = 3
                self.statusCode = "\(code)"
            case .reqHeaders(_):
                self.ruleTypeIndex = 0
            }
        }
    }

    private func saveAction() {
        let action: RuleAction
        switch ruleTypeIndex {
        case 0:
            let port = Int(targetPort) ?? 80
            action = .hostRedirect(host: targetHost, port: port)
        case 1:
            let code = Int(mockStatusCode) ?? 200
            action = .mapLocal(body: mockBody, contentType: "application/json", statusCode: code)
        case 2:
            action = .mapRemote(targetUrl: remoteUrl)
        case 3:
            let code = Int(statusCode) ?? 503
            action = .statusCode(code: code)
        default:
            action = .hostRedirect(host: "127.0.0.1", port: 8080)
        }

        let rule = ProxyRule(
            id: ruleId,
            isEnabled: isEnabled,
            pattern: pattern.trimmingCharacters(in: .whitespaces),
            action: action,
            comment: comment.isEmpty ? nil : comment
        )

        viewModel.saveRule(rule)
    }
}
