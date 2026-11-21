import Foundation
import SwiftUI
import Combine
import AppKit

public enum AppMode: String, CaseIterable, Identifiable {
    case visual = "可视化模式"
    case config = "配置代码模式"

    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .visual: return "square.grid.2x2"
        case .config: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

public enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light = "浅色模式"
    case dark = "深色模式"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
public final class ProxyViewModel: ObservableObject, ProxyServerDelegate {
    // Core Engine & Server
    public let ruleEngine: RuleEngine
    public let proxyServer: ProxyServer

    // State Variables
    @Published public var rules: [ProxyRule] = []
    @Published public var rawConfigText: String = ""
    @Published public var currentMode: AppMode = .visual
    @Published public var appearanceMode: AppearanceMode = .system
    @Published public var filterType: RuleFilterType = .all
    @Published public var searchText: String = ""

    @Published public var isServerRunning: Bool = false
    @Published public var serverPort: UInt16 = 9898
    @Published public var totalRequests: Int = 0
    @Published public var matchedRequests: Int = 0
    @Published public var memoryUsageMB: Double = 0.0

    // UI Sheets & Messages
    @Published public var isShowingRuleSheet: Bool = false
    @Published public var editingRule: ProxyRule? = nil
    @Published public var alertMessage: String? = nil
    @Published public var isShowingAlert: Bool = false

    private var memoryTimer: AnyCancellable?
    private var isInternalSyncing: Bool = false

    public init() {
        // Initialize default sample rules showcase
        let defaultText = """
        # ========================================================
        # WhistFlow 默认规则 (兼容 Whistle 语法)
        # ========================================================

        # 1. Hosts 域名映射：将线上 API 映射至本地研发端口
        api.example.com 127.0.0.1:3000 # 本地微服务

        # 2. Map Local / Mock：拦截接口直接返回模拟 JSON
        mock.example.com/api/user resBody://({"id":1001,"name":"Antigravity","role":"admin","active":true}) # 用户信息 Mock

        # 3. Map Remote 远程路径重定向
        cdn.example.com/static https://unpkg.com # CDN 静态重定向

        # 4. 状态码测试 (模拟 503 熔断)
        # error.example.com statusCode://503 # 模拟服务熔断维护
        """

        self.rawConfigText = defaultText
        let initialRules = RuleEngine.parseWhistleRules(text: defaultText)
        self.rules = initialRules
        self.ruleEngine = RuleEngine(rules: initialRules)
        self.proxyServer = ProxyServer(port: 9898, ruleEngine: self.ruleEngine)

        self.proxyServer.delegate = self

        // Start Proxy Server automatically
        startProxy()

        // Start Memory Monitor Timer
        startMemoryMonitoring()
    }

    // MARK: - Server Control
    public func startProxy() {
        do {
            try proxyServer.start()
            isServerRunning = true
            serverPort = proxyServer.activePort
        } catch {
            showError("启动代理服务失败: \(error.localizedDescription)")
            isServerRunning = false
        }
    }

    public func stopProxy() {
        proxyServer.stop()
        isServerRunning = false
    }

    public func toggleProxy() {
        if isServerRunning {
            stopProxy()
        } else {
            startProxy()
        }
    }

    public func restartProxy(port: UInt16) {
        do {
            try proxyServer.restart(withPort: port)
            self.serverPort = port
            self.isServerRunning = true
        } catch {
            showError("重启代理服务失败: \(error.localizedDescription)")
        }
    }

    // MARK: - ProxyServerDelegate
    nonisolated public func proxyServerDidUpdateStats(total: Int, matched: Int) {
        Task { @MainActor in
            self.totalRequests = total
            self.matchedRequests = matched
        }
    }

    nonisolated public func proxyServerDidUpdateRulesFromApi(_ rules: [ProxyRule]) {
        Task { @MainActor in
            self.isInternalSyncing = true
            self.rules = rules
            self.rawConfigText = RuleEngine.serializeToWhistle(rules: rules)
            self.isInternalSyncing = false
        }
    }

    nonisolated public func proxyServerDidUpdateAppearance(_ mode: String) {
        Task { @MainActor in
            if mode == "light" {
                self.appearanceMode = .light
            } else if mode == "dark" {
                self.appearanceMode = .dark
            } else {
                self.appearanceMode = .system
            }
        }
    }

    nonisolated public func proxyServerDidUpdateAppMode(_ mode: String) {
        Task { @MainActor in
            if mode == "config" {
                self.currentMode = .config
            } else {
                self.currentMode = .visual
            }
        }
    }

    // MARK: - Appearance Mode Control
    public func cycleAppearance() {
        switch appearanceMode {
        case .system: appearanceMode = .light
        case .light: appearanceMode = .dark
        case .dark: appearanceMode = .system
        }
    }

    // MARK: - Real-time Rule Management (Visual Mode)
    public func onRuleMutated() {
        commitRulesChange()
    }

    public func toggleRule(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[index].isEnabled.toggle()
        commitRulesChange()
    }

    public func deleteRule(id: UUID) {
        rules.removeAll { $0.id == id }
        commitRulesChange()
    }

    public func duplicateRule(rule: ProxyRule) {
        var copy = rule
        copy.id = UUID()
        copy.pattern += "-copy"
        copy.createdAt = Date()
        rules.insert(copy, at: 0)
        commitRulesChange()
    }

    public func saveRule(_ rule: ProxyRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.insert(rule, at: 0)
        }
        commitRulesChange()
    }

    // MARK: - Real-time Synchronization
    /// Called when rules are modified visually
    private func commitRulesChange() {
        guard !isInternalSyncing else { return }
        isInternalSyncing = true
        defer { isInternalSyncing = false }

        // Update active running rule engine immediately
        ruleEngine.updateRules(rules)

        // Sync text representation
        self.rawConfigText = RuleEngine.serializeToWhistle(rules: rules)
    }

    /// Called when user edits config in Configuration Mode
    public func onConfigTextUpdated(_ newText: String) {
        guard !isInternalSyncing else { return }
        self.rawConfigText = newText

        // Parse into rules
        let parsed = RuleEngine.parseWhistleRules(text: newText)
        var updated: [ProxyRule] = []
        for var p in parsed {
            if let existing = self.rules.first(where: { $0.pattern == p.pattern && $0.action == p.action }) {
                p.id = existing.id
            }
            updated.append(p)
        }
        self.rules = updated

        // Update active running rule engine immediately
        ruleEngine.updateRules(updated)
    }

    // MARK: - Filtered Rules
    public var filteredRules: [ProxyRule] {
        return rules.filter { rule in
            // Filter by category
            let matchesCategory: Bool
            switch filterType {
            case .all:
                matchesCategory = true
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

            // Filter by search query
            if searchText.isEmpty { return true }
            let query = searchText.lowercased()
            return rule.pattern.lowercased().contains(query) ||
                   rule.action.displayTarget.lowercased().contains(query) ||
                   (rule.comment?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: - Import & Export
    public func exportConfiguration() {
        let panel = NSSavePanel()
        panel.title = "导出 WhistFlow 代理配置"
        panel.nameFieldStringValue = "whistflow_rules.txt"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try rawConfigText.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                showError("导出文件失败: \(error.localizedDescription)")
            }
        }
    }

    public func importConfiguration() {
        let panel = NSOpenPanel()
        panel.title = "导入 WhistFlow 代理配置"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, .json]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                onConfigTextUpdated(content)
            } catch {
                showError("读取导入文件失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Memory Usage Tracker
    private func startMemoryMonitoring() {
        updateMemoryUsage()
        memoryTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMemoryUsage()
            }
    }

    private func updateMemoryUsage() {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.phys_footprint) / (1024.0 * 1024.0)
            self.memoryUsageMB = (usedMB * 10).rounded() / 10
        }
    }

    private func showError(_ msg: String) {
        self.alertMessage = msg
        self.isShowingAlert = true
    }
}
