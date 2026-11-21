import Foundation
import SwiftUI

// MARK: - Rule Action Definition
public enum RuleAction: Equatable, Codable, Sendable {
    case hostRedirect(host: String, port: Int)
    case mapRemote(targetUrl: String)
    case mapLocal(body: String, contentType: String, statusCode: Int)
    case reqHeaders(headers: [String: String])
    case statusCode(code: Int)

    public var typeName: String {
        switch self {
        case .hostRedirect: return "HOST"
        case .mapRemote: return "REMOTE"
        case .mapLocal: return "MOCK"
        case .reqHeaders: return "HEADER"
        case .statusCode: return "STATUS"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .hostRedirect:
            return Color(red: 0.18, green: 0.52, blue: 0.95) // Vibrant Blue
        case .mapRemote:
            return Color(red: 0.55, green: 0.35, blue: 0.95) // Purple
        case .mapLocal:
            return Color(red: 0.15, green: 0.72, blue: 0.55) // Emerald Mint
        case .reqHeaders:
            return Color(red: 0.95, green: 0.58, blue: 0.15) // Amber
        case .statusCode:
            return Color(red: 0.92, green: 0.30, blue: 0.30) // Red
        }
    }

    public var displayTarget: String {
        switch self {
        case .hostRedirect(let host, let port):
            return "\(host):\(port)"
        case .mapRemote(let url):
            return url
        case .mapLocal(let body, _, let code):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = trimmed.count > 40 ? String(trimmed.prefix(37)) + "..." : trimmed
            return "\(code) -> \(preview)"
        case .reqHeaders(let headers):
            return headers.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        case .statusCode(let code):
            return "Status \(code)"
        }
    }
}

// MARK: - Proxy Rule Model
public struct ProxyRule: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var isEnabled: Bool
    public var pattern: String
    public var action: RuleAction
    public var comment: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        pattern: String,
        action: RuleAction,
        comment: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.pattern = pattern
        self.action = action
        self.comment = comment
        self.createdAt = createdAt
    }

    /// Converts the structured rule into a Whistle-compatible text rule line
    public func toWhistleLine() -> String {
        var line = ""
        switch action {
        case .hostRedirect(let host, let port):
            line = "\(pattern) \(host):\(port)"
        case .mapRemote(let targetUrl):
            line = "\(pattern) \(targetUrl)"
        case .mapLocal(let body, _, let statusCode):
            let escapedBody = body.replacingOccurrences(of: "\n", with: "\\n")
            if statusCode != 200 {
                line = "\(pattern) resBody://(\(escapedBody)) statusCode://\(statusCode)"
            } else {
                line = "\(pattern) resBody://(\(escapedBody))"
            }
        case .reqHeaders(let headers):
            if let data = try? JSONSerialization.data(withJSONObject: headers, options: [.sortedKeys]),
               let jsonStr = String(data: data, encoding: .utf8) {
                line = "\(pattern) reqHeaders://\(jsonStr)"
            } else {
                line = "\(pattern) reqHeaders://{}"
            }
        case .statusCode(let code):
            line = "\(pattern) statusCode://\(code)"
        }

        if let comment = comment, !comment.isEmpty {
            line += " # \(comment)"
        }

        if !isEnabled {
            return "# \(line)"
        }
        return line
    }
}

// MARK: - Proxy Stats Model
public struct ProxyStats: Equatable {
    public var totalRequests: Int = 0
    public var matchedRequests: Int = 0
    public var startTime: Date = Date()
    public var memoryUsageMB: Double = 0.0

    public init() {}
}

// MARK: - App Filter Type
public enum RuleFilterType: String, CaseIterable, Identifiable {
    case all = "全部"
    case host = "HOST 映射"
    case mock = "MOCK 模拟"
    case remote = "远程重定向"
    case header = "Header 注入"

    public var id: String { rawValue }
}
