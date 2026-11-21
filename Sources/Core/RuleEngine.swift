import Foundation

// MARK: - Matched Rule Result
public struct MatchedRuleResult {
    public let rule: ProxyRule
    public let action: RuleAction
}

// MARK: - Rule Engine
public final class RuleEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var rules: [ProxyRule] = []

    public init(rules: [ProxyRule] = []) {
        self.rules = rules
    }

    /// Update rules atomically
    public func updateRules(_ newRules: [ProxyRule]) {
        lock.lock()
        defer { lock.unlock() }
        self.rules = newRules
    }

    /// Read all current rules
    public func getRules() -> [ProxyRule] {
        lock.lock()
        defer { lock.unlock() }
        return self.rules
    }

    /// Fast rule match for an incoming request
    public func match(host: String, path: String = "/") -> MatchedRuleResult? {
        lock.lock()
        defer { lock.unlock() }

        let normalizedHost = host.lowercased()
        let fullPath = path.hasPrefix("/") ? path : "/\(path)"
        let fullUrlString = "\(normalizedHost)\(fullPath)"

        for rule in rules where rule.isEnabled {
            let pattern = rule.pattern.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // 1. Wildcard match (*.example.com)
            if pattern.hasPrefix("*.") {
                let suffix = String(pattern.dropFirst(2))
                if normalizedHost == suffix || normalizedHost.hasSuffix("." + suffix) {
                    return MatchedRuleResult(rule: rule, action: rule.action)
                }
            }

            // 2. Exact or Prefix match on host or host+path
            if normalizedHost == pattern || fullUrlString.hasPrefix(pattern) || pattern == "*" {
                return MatchedRuleResult(rule: rule, action: rule.action)
            }

            // 3. Regex match support (if wrapped in /.../)
            if pattern.hasPrefix("/") && pattern.hasSuffix("/") && pattern.count > 2 {
                let regexBody = String(pattern.dropFirst().dropLast())
                if let regex = try? NSRegularExpression(pattern: regexBody, options: [.caseInsensitive]) {
                    let range = NSRange(location: 0, length: fullUrlString.utf16.count)
                    if regex.firstMatch(in: fullUrlString, options: [], range: range) != nil {
                        return MatchedRuleResult(rule: rule, action: rule.action)
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Parser: Whistle Text to [ProxyRule]
    public static func parseWhistleRules(text: String) -> [ProxyRule] {
        var parsed: [ProxyRule] = []
        let lines = text.components(separatedBy: .newlines)

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            var isEnabled = true
            var lineContent = trimmed

            // Check if commented out (disabled)
            if lineContent.hasPrefix("#") {
                isEnabled = false
                lineContent = lineContent.dropFirst().trimmingCharacters(in: .whitespaces)
                // If it's pure comment without rule syntax, skip creating a phantom rule unless it looks like a rule
                if lineContent.isEmpty || lineContent.hasPrefix("=") || lineContent.hasPrefix("-") {
                    continue
                }
            }

            // Separate optional inline comment: "rule # comment"
            var inlineComment: String? = nil
            if let commentRange = lineContent.range(of: " # ") {
                inlineComment = String(lineContent[commentRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                lineContent = String(lineContent[..<commentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            }

            // Tokenize by whitespace
            let tokens = lineContent.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard tokens.count >= 2 else { continue }

            let pattern = tokens[0]
            guard isValidPattern(pattern) else { continue }

            let operatorPart = tokens[1...].joined(separator: " ")

            // Parse Action
            if let action = parseAction(operatorPart: operatorPart) {
                let rule = ProxyRule(
                    id: UUID(),
                    isEnabled: isEnabled,
                    pattern: pattern,
                    action: action,
                    comment: inlineComment
                )
                parsed.append(rule)
            }
        }

        return parsed
    }

    private static func isValidPattern(_ str: String) -> Bool {
        if str.isEmpty { return false }
        if str == "*" { return true }
        if str.hasPrefix("/") && str.hasSuffix("/") { return true }
        // Avoid numbering like "1.", "2.", "=="
        if str.hasSuffix(".") && str.filter({ $0 == "." }).count == 1 { return false }
        for scalar in str.unicodeScalars {
            if scalar.value >= 0x4e00 && scalar.value <= 0x9fa5 { return false }
        }
        return str.contains(".") || str.contains("/") || str == "localhost"
    }

    private static func isValidHostOrIp(_ str: String) -> Bool {
        if str.isEmpty { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        return str.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Action Parser
    private static func parseAction(operatorPart: String) -> RuleAction? {
        let trimmed = operatorPart.trimmingCharacters(in: .whitespaces)

        // 1. Map Remote (URL)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return .mapRemote(targetUrl: trimmed)
        }

        // 2. Map Local / resBody
        if trimmed.hasPrefix("resBody://") {
            var body = String(trimmed.dropFirst("resBody://".count))
            if body.hasPrefix("(") && body.hasSuffix(")") {
                body = String(body.dropFirst().dropLast())
            }
            body = body.replacingOccurrences(of: "\\n", with: "\n")
            var statusCode = 200
            if let statusRange = trimmed.range(of: "statusCode://") {
                let statusStr = String(trimmed[statusRange.upperBound...]).components(separatedBy: .whitespaces).first ?? "200"
                statusCode = Int(statusStr) ?? 200
            }
            return .mapLocal(body: body, contentType: "application/json", statusCode: statusCode)
        }

        // 3. Status Code
        if trimmed.hasPrefix("statusCode://") {
            let codeStr = String(trimmed.dropFirst("statusCode://".count)).trimmingCharacters(in: .whitespaces)
            let code = Int(codeStr) ?? 200
            return .statusCode(code: code)
        }

        // 4. Request Headers
        if trimmed.hasPrefix("reqHeaders://") {
            let jsonStr = String(trimmed.dropFirst("reqHeaders://".count)).trimmingCharacters(in: .whitespaces)
            if let data = jsonStr.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                return .reqHeaders(headers: dict)
            }
            return .reqHeaders(headers: [:])
        }

        // 5. Host & Port Redirect (e.g. "127.0.0.1:8080" or "localhost:3000" or "10.0.0.1")
        let hostPortParts = trimmed.components(separatedBy: ":")
        if hostPortParts.count == 2, let port = Int(hostPortParts[1]), isValidHostOrIp(hostPortParts[0]), port > 0, port <= 65535 {
            return .hostRedirect(host: hostPortParts[0], port: port)
        } else if hostPortParts.count == 1, isValidHostOrIp(hostPortParts[0]) {
            let candidate = hostPortParts[0]
            if candidate == "localhost" || candidate.contains(".") {
                return .hostRedirect(host: candidate, port: 80)
            }
        }

        return nil
    }

    // MARK: - Serializer: [ProxyRule] to Whistle Text
    public static func serializeToWhistle(rules: [ProxyRule]) -> String {
        var lines: [String] = []
        lines.append("# ========================================================")
        lines.append("# SimpleProxy Proxy Rules (Compatible with Whistle syntax)")
        lines.append("# Format: <pattern> <operator>")
        lines.append("# ========================================================")
        lines.append("")

        for rule in rules {
            lines.append(rule.toWhistleLine())
        }

        return lines.joined(separator: "\n")
    }
}
