// Transmission.swift — the network engine. The ONLY file that touches the
// network. HTTP Basic auth, Transmission's X-Transmission-Session-Id handshake
// (a 409 hands you the id; you retry with it), then a torrent-add. Session id is
// cached and refreshed on the next 409.

import Foundation

enum SendOutcome {
    case added(String)
    case duplicate(String)
    case authFailed
    case failed(String)
}

enum TestOutcome {
    case ok
    case authFailed
    case failed(String)
}

actor TransmissionClient {
    struct Config {
        var rpcURL: URL
        var username: String
        var password: String

        /// nil when no credentials are set — the server runs without RPC auth,
        /// so we send no Authorization header at all (not an empty one).
        var authHeader: String? {
            guard !username.isEmpty || !password.isEmpty else { return nil }
            return "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
        }
    }

    private var sessionId: String?
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 20
        return URLSession(configuration: cfg)
    }()

    func test(_ config: Config) async -> TestOutcome {
        let body = Data(#"{"method":"session-get"}"#.utf8)
        do {
            let (status, _) = try await rpc(config, body: body)
            switch status {
            case 200: return .ok
            case 401: return .authFailed
            default:  return .failed("HTTP \(status)")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func add(_ magnet: Magnet, config: Config) async -> SendOutcome {
        let name = magnet.displayName
        let payload: [String: Any] = [
            "method": "torrent-add",
            "arguments": ["filename": magnet.url.absoluteString],
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return .failed("could not encode request")
        }
        do {
            let (status, data) = try await rpc(config, body: body)
            if status == 401 { return .authFailed }
            guard status == 200 else { return .failed("HTTP \(status)") }

            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            guard (json?["result"] as? String) == "success" else {
                return .failed((json?["result"] as? String) ?? "unexpected response")
            }
            let args = json?["arguments"] as? [String: Any]
            return args?["torrent-duplicate"] != nil ? .duplicate(name) : .added(name)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - handshake

    /// Sends one RPC body; on a 409 it adopts the offered session id and retries once.
    private func rpc(_ config: Config, body: Data) async throws -> (status: Int, data: Data) {
        var (status, data, offeredId) = try await perform(config, body: body)
        if status == 409, let offeredId {
            sessionId = offeredId
            (status, data, _) = try await perform(config, body: body)
        }
        return (status, data)
    }

    private func perform(_ config: Config, body: Data) async throws -> (Int, Data, String?) {
        var req = URLRequest(url: config.rpcURL)
        req.httpMethod = "POST"
        if let auth = config.authHeader {
            req.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sessionId {
            req.setValue(sessionId, forHTTPHeaderField: "X-Transmission-Session-Id")
        }
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (http.statusCode, data, http.value(forHTTPHeaderField: "X-Transmission-Session-Id"))
    }
}
