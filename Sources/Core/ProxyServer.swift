import Foundation
import Network

// MARK: - Proxy Server Delegate / Notification
public protocol ProxyServerDelegate: AnyObject {
    func proxyServerDidUpdateStats(total: Int, matched: Int)
}

// MARK: - Proxy Server
public final class ProxyServer: @unchecked Sendable {
    public let ruleEngine: RuleEngine
    public weak var delegate: ProxyServerDelegate?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.whistflow.proxy.server", attributes: .concurrent)
    private var isRunning: Bool = false
    public private(set) var port: UInt16

    private var totalRequests: Int = 0
    private var matchedRequests: Int = 0
    private let statsLock = NSLock()

    public init(port: UInt16 = 9898, ruleEngine: RuleEngine) {
        self.port = port
        self.ruleEngine = ruleEngine
    }

    /// Start the proxy server
    public func start() throws {
        guard !isRunning else { return }

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        guard let nwPort = NWEndpoint.Port(rawValue: self.port) else {
            throw NSError(domain: "ProxyServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid port \(port)"])
        }

        let listener = try NWListener(using: params, on: nwPort)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                print("[WhistFlow] Proxy Server listening on 127.0.0.1:\(self.port)")
            case .failed(let error):
                print("[WhistFlow] Proxy Server failed: \(error)")
                self.stop()
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleClientConnection(connection)
        }

        listener.start(queue: queue)
        self.listener = listener
        self.isRunning = true
    }

    /// Stop the proxy server
    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        print("[WhistFlow] Proxy Server stopped")
    }

    /// Dynamic update port
    public func restart(withPort newPort: UInt16) throws {
        stop()
        self.port = newPort
        try start()
    }

    public var activePort: UInt16 {
        return port
    }

    public var isServerRunning: Bool {
        return isRunning
    }

    public func getStats() -> (total: Int, matched: Int) {
        statsLock.lock()
        defer { statsLock.unlock() }
        return (totalRequests, matchedRequests)
    }

    private func incrementStats(matched: Bool) {
        statsLock.lock()
        totalRequests += 1
        if matched { matchedRequests += 1 }
        let total = totalRequests
        let match = matchedRequests
        statsLock.unlock()

        delegate?.proxyServerDidUpdateStats(total: total, matched: match)
    }

    // MARK: - Handle Client Connection
    private func handleClientConnection(_ clientConn: NWConnection) {
        clientConn.start(queue: queue)

        // Read initial HTTP request header
        clientConn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty else {
                clientConn.cancel()
                return
            }

            guard let requestString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                clientConn.cancel()
                return
            }

            let lines = requestString.components(separatedBy: "\r\n")
            guard let firstLine = lines.first, !firstLine.isEmpty else {
                clientConn.cancel()
                return
            }

            let parts = firstLine.components(separatedBy: " ")
            guard parts.count >= 2 else {
                clientConn.cancel()
                return
            }

            let method = parts[0].uppercased()
            let uri = parts[1]

            // 1. Check for CONNECT tunneling (HTTPS)
            if method == "CONNECT" {
                self.handleConnectTunnel(clientConn: clientConn, uri: uri)
                return
            }

            // 2. Standard HTTP Request
            self.handleHttpRequest(clientConn: clientConn, rawData: data, requestString: requestString, method: method, uri: uri, lines: lines)
        }
    }

    // MARK: - HTTPS CONNECT Tunnel
    private func handleConnectTunnel(clientConn: NWConnection, uri: String) {
        // uri is usually "domain.com:443"
        let hostPort = uri.components(separatedBy: ":")
        let host = hostPort[0]
        let defaultPort = UInt16(hostPort.count > 1 ? (UInt16(hostPort[1]) ?? 443) : 443)

        var targetHost = host
        var targetPort = defaultPort
        var matched = false

        if let match = ruleEngine.match(host: host) {
            matched = true
            switch match.action {
            case .hostRedirect(let rHost, let rPort):
                targetHost = rHost
                targetPort = UInt16(rPort)
            default:
                break
            }
        }

        self.incrementStats(matched: matched)

        // Connect to upstream target
        guard let nwTargetPort = NWEndpoint.Port(rawValue: targetPort) else {
            clientConn.cancel()
            return
        }

        let upstream = NWConnection(host: NWEndpoint.Host(targetHost), port: nwTargetPort, using: .tcp)
        upstream.stateUpdateHandler = { state in
            if case .ready = state {
                // Send 200 Connection Established to client
                let response = "HTTP/1.1 200 Connection Established\r\nServer: WhistFlow\r\n\r\n"
                clientConn.send(content: response.data(using: .utf8), completion: .contentProcessed({ sendError in
                    if sendError == nil {
                        // Start bidirectional streaming
                        self.pipe(connA: clientConn, connB: upstream)
                        self.pipe(connA: upstream, connB: clientConn)
                    } else {
                        clientConn.cancel()
                        upstream.cancel()
                    }
                }))
            } else if case .failed(_) = state {
                let errResp = "HTTP/1.1 502 Bad Gateway\r\n\r\n"
                clientConn.send(content: errResp.data(using: .utf8), completion: .contentProcessed({ _ in
                    clientConn.cancel()
                }))
            }
        }
        upstream.start(queue: queue)
    }

    // MARK: - HTTP Request Handling & Rule Matching
    private func handleHttpRequest(
        clientConn: NWConnection,
        rawData: Data,
        requestString: String,
        method: String,
        uri: String,
        lines: [String]
    ) {
        // Extract Host
        var host = ""
        var path = uri

        if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
            if let url = URL(string: uri) {
                host = url.host ?? ""
                path = url.path.isEmpty ? "/" : url.path
                if let query = url.query { path += "?\(query)" }
            }
        }

        if host.isEmpty {
            for line in lines {
                if line.lowercased().hasPrefix("host:") {
                    host = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    if let colonIdx = host.firstIndex(of: ":") {
                        host = String(host[..<colonIdx])
                    }
                    break
                }
            }
        }

        // Match Rule Engine
        let matchResult = ruleEngine.match(host: host, path: path)
        self.incrementStats(matched: matchResult != nil)

        if let match = matchResult {
            switch match.action {
            case .mapLocal(let body, let contentType, let statusCode):
                // Return Mock Response directly
                self.sendMockResponse(clientConn: clientConn, body: body, contentType: contentType, statusCode: statusCode)
                return

            case .statusCode(let code):
                // Return Status Code directly
                self.sendStatusCodeResponse(clientConn: clientConn, code: code)
                return

            case .hostRedirect(let targetHost, let targetPort):
                // Forward request to redirect host
                self.forwardHttpRequest(clientConn: clientConn, rawData: rawData, targetHost: targetHost, targetPort: UInt16(targetPort))
                return

            case .mapRemote(let targetUrlStr):
                if let targetUrl = URL(string: targetUrlStr), let tHost = targetUrl.host {
                    let tPort = UInt16(targetUrl.port ?? (targetUrl.scheme == "https" ? 443 : 80))
                    self.forwardHttpRequest(clientConn: clientConn, rawData: rawData, targetHost: tHost, targetPort: tPort)
                    return
                }

            case .reqHeaders(_):
                // Forward with custom headers
                break
            }
        }

        // Default: Forward to original host (port 80)
        let defaultPort: UInt16 = 80
        self.forwardHttpRequest(clientConn: clientConn, rawData: rawData, targetHost: host.isEmpty ? "127.0.0.1" : host, targetPort: defaultPort)
    }

    // MARK: - Mock Response Helper
    private func sendMockResponse(clientConn: NWConnection, body: String, contentType: String, statusCode: Int) {
        let bodyData = body.data(using: .utf8) ?? Data()
        let statusText = (statusCode == 200) ? "OK" : "Status \(statusCode)"
        let headers = [
            "HTTP/1.1 \(statusCode) \(statusText)",
            "Server: WhistFlow",
            "Content-Type: \(contentType); charset=utf-8",
            "Content-Length: \(bodyData.count)",
            "Access-Control-Allow-Origin: *",
            "Connection: close",
            "\r\n"
        ].joined(separator: "\r\n")

        var fullData = headers.data(using: .utf8) ?? Data()
        fullData.append(bodyData)

        clientConn.send(content: fullData, completion: .contentProcessed({ _ in
            clientConn.cancel()
        }))
    }

    // MARK: - Status Code Response Helper
    private func sendStatusCodeResponse(clientConn: NWConnection, code: Int) {
        let response = "HTTP/1.1 \(code) Status \(code)\r\nServer: WhistFlow\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        clientConn.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
            clientConn.cancel()
        }))
    }

    // MARK: - Forward HTTP Request
    private func forwardHttpRequest(clientConn: NWConnection, rawData: Data, targetHost: String, targetPort: UInt16) {
        guard let nwPort = NWEndpoint.Port(rawValue: targetPort) else {
            clientConn.cancel()
            return
        }

        let upstream = NWConnection(host: NWEndpoint.Host(targetHost), port: nwPort, using: .tcp)
        upstream.stateUpdateHandler = { state in
            if case .ready = state {
                // Send client request to upstream
                upstream.send(content: rawData, completion: .contentProcessed({ error in
                    if error == nil {
                        self.pipe(connA: clientConn, connB: upstream)
                        self.pipe(connA: upstream, connB: clientConn)
                    } else {
                        clientConn.cancel()
                        upstream.cancel()
                    }
                }))
            } else if case .failed(_) = state {
                let errResp = "HTTP/1.1 502 Bad Gateway (WhistFlow Target Unreachable)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                clientConn.send(content: errResp.data(using: .utf8), completion: .contentProcessed({ _ in
                    clientConn.cancel()
                }))
            }
        }
        upstream.start(queue: queue)
    }

    // MARK: - Full Duplex Pipe
    private func pipe(connA: NWConnection, connB: NWConnection) {
        connA.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                connB.send(content: data, completion: .contentProcessed({ sendErr in
                    if sendErr == nil && !isComplete {
                        self.pipe(connA: connA, connB: connB)
                    } else {
                        connA.cancel()
                        connB.cancel()
                    }
                }))
            } else {
                connA.cancel()
                connB.cancel()
            }
        }
    }
}
