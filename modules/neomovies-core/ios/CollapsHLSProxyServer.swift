import Foundation
import Network

final class CollapsHLSProxyServer {
    private let masterURL: URL
    private let headers: [String: String]
    private let queue = DispatchQueue(label: "ru.neomovies.hls-proxy")
    private var listener: NWListener?

    init(masterURL: URL, headers: [String: String]) {
        self.masterURL = masterURL
        self.headers = headers
    }

    func start() throws -> URL {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener

        let startSemaphore = DispatchSemaphore(value: 0)
        var startError: Error?

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                startSemaphore.signal()
            case .failed(let error):
                startError = error
                startSemaphore.signal()
            default:
                break
            }
        }
        listener.start(queue: queue)

        if startSemaphore.wait(timeout: .now() + 3) == .timedOut {
            throw CollapsHLSProxyError.startTimedOut
        }
        if let startError {
            throw startError
        }
        guard let port = listener.port?.rawValue,
              let url = URL(string: "http://127.0.0.1:\(port)/master.m3u8") else {
            throw CollapsHLSProxyError.invalidLocalURL
        }

        return url
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }

            guard let data,
                  let rawRequest = String(data: data, encoding: .utf8),
                  let request = self.request(from: rawRequest) else {
                self.send(status: 400, contentType: "text/plain", body: Data("Bad Request".utf8), on: connection)
                return
            }

            Task {
                let response = await self.response(for: request)
                self.send(status: response.status, contentType: response.contentType, headers: response.headers, body: response.body, on: connection)
            }
        }
    }

    private func response(for request: CollapsHLSProxyRequest) async -> CollapsHLSProxyResponse {
        if request.method == "HEAD" {
            return CollapsHLSProxyResponse(status: 200, contentType: "application/octet-stream", headers: ["Accept-Ranges": "bytes"], body: Data())
        }

        if request.path.hasPrefix("/master.m3u8") {
            return await playlistResponse(for: masterURL, request: request)
        }

        guard request.path.hasPrefix("/proxy"),
              let originalURL = originalURL(from: request.path) else {
            return CollapsHLSProxyResponse(status: 404, contentType: "text/plain", body: Data("Not Found".utf8))
        }

        if originalURL.path.lowercased().contains(".m3u8") {
            return await playlistResponse(for: originalURL, request: request)
        }

        return await dataResponse(for: originalURL, request: request)
    }

    private func playlistResponse(for url: URL, request: CollapsHLSProxyRequest) async -> CollapsHLSProxyResponse {
        do {
            let fetched = try await fetch(url, request: request)
            guard let playlist = String(data: fetched.data, encoding: .utf8) else {
                return CollapsHLSProxyResponse(status: 502, contentType: "text/plain", body: Data("Invalid playlist".utf8))
            }

            let rewritten = rewritePlaylist(playlist, baseURL: url)
            return CollapsHLSProxyResponse(
                status: 200,
                contentType: "application/vnd.apple.mpegurl",
                headers: ["Accept-Ranges": "bytes"],
                body: Data(rewritten.utf8)
            )
        } catch {
            return CollapsHLSProxyResponse(status: 502, contentType: "text/plain", body: Data("Playlist fetch failed".utf8))
        }
    }

    private func dataResponse(for url: URL, request: CollapsHLSProxyRequest) async -> CollapsHLSProxyResponse {
        do {
            let fetched = try await fetch(url, request: request)
            return CollapsHLSProxyResponse(
                status: fetched.status,
                contentType: fetched.contentType ?? contentType(for: url),
                headers: fetched.headers.merging(["Accept-Ranges": "bytes"]) { current, _ in current },
                body: fetched.data
            )
        } catch {
            return CollapsHLSProxyResponse(status: 502, contentType: "text/plain", body: Data("Segment fetch failed".utf8))
        }
    }

    private func fetch(_ url: URL, request incomingRequest: CollapsHLSProxyRequest) async throws -> CollapsHLSFetchResponse {
        var request = URLRequest(url: url)
        headers.forEach { key, value in request.setValue(value, forHTTPHeaderField: key) }
        if let range = incomingRequest.headers["range"] {
            request.setValue(range, forHTTPHeaderField: "Range")
        }
        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue("*/*", forHTTPHeaderField: "Accept")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw CollapsHLSProxyError.fetchFailed
        }
        return CollapsHLSFetchResponse(
            status: httpResponse.statusCode,
            contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"),
            headers: forwardedResponseHeaders(from: httpResponse),
            data: data
        )
    }

    private func rewritePlaylist(_ playlist: String, baseURL: URL) -> String {
        playlist
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { rewritePlaylistLine($0, baseURL: baseURL) }
            .joined(separator: "\n")
    }

    private func rewritePlaylistLine(_ line: String, baseURL: URL) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return line }
        if trimmed.hasPrefix("#") {
            return rewriteAttributeURIs(in: line, baseURL: baseURL)
        }
        guard let absoluteURL = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL else { return line }
        return proxyURL(for: absoluteURL).absoluteString
    }

    private func rewriteAttributeURIs(in line: String, baseURL: URL) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"URI=\"([^\"]+)\""#) else { return line }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        var rewritten = line
        for match in regex.matches(in: line, range: nsRange).reversed() {
            guard let uriRange = Range(match.range(at: 1), in: line) else { continue }
            let rawURI = String(line[uriRange])
            guard rawURI != "none",
                  let absoluteURL = URL(string: rawURI, relativeTo: baseURL)?.absoluteURL else {
                continue
            }
            rewritten.replaceSubrange(uriRange, with: proxyURL(for: absoluteURL).absoluteString)
        }
        return rewritten
    }

    private func proxyURL(for url: URL) -> URL {
        let encoded = Data(url.absoluteString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let port = listener?.port?.rawValue ?? 0
        return URL(string: "http://127.0.0.1:\(port)/proxy?url=\(encoded)")!
    }

    private func originalURL(from path: String) -> URL? {
        guard let components = URLComponents(string: "http://127.0.0.1\(path)"),
              let value = components.queryItems?.first(where: { $0.name == "url" })?.value else {
            return nil
        }
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let urlString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return URL(string: urlString)
    }

    private func request(from rawRequest: String) -> CollapsHLSProxyRequest? {
        let lines = rawRequest.components(separatedBy: "\r\n")
        let firstLine = lines.first ?? ""
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard !line.isEmpty else { break }
            let split = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard split.count == 2 else { continue }
            headers[split[0].lowercased()] = split[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return CollapsHLSProxyRequest(method: String(parts[0]).uppercased(), path: String(parts[1]), headers: headers)
    }

    private func forwardedResponseHeaders(from response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for key in ["Content-Range", "Accept-Ranges", "Cache-Control", "ETag", "Last-Modified"] {
            if let value = response.value(forHTTPHeaderField: key) {
                headers[key] = value
            }
        }
        return headers
    }

    private func send(status: Int, contentType: String, headers: [String: String] = [:], body: Data, on connection: NWConnection) {
        let reason = statusReason(for: status)
        var headerLines = [
            "HTTP/1.1 \(status) \(reason)",
            "Content-Type: \(contentType)",
            "Content-Length: \(body.count)"
        ]
        headerLines.append(contentsOf: headers.map { "\($0.key): \($0.value)" })
        headerLines.append("Access-Control-Allow-Origin: *")
        headerLines.append("Connection: close")
        let header = headerLines.joined(separator: "\r\n") + "\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func contentType(for url: URL) -> String {
        let path = url.path.lowercased()
        if path.contains(".vtt") || path.contains(".webvtt") { return "text/vtt" }
        if path.contains(".m4s") || path.contains(".mp4") { return "video/mp4" }
        if path.contains(".aac") { return "audio/aac" }
        return "video/mp2t"
    }

    private func statusReason(for status: Int) -> String {
        switch status {
        case 206: return "Partial Content"
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        default: return "Bad Gateway"
        }
    }
}

private struct CollapsHLSProxyResponse {
    let status: Int
    let contentType: String
    var headers: [String: String] = [:]
    let body: Data
}

private struct CollapsHLSProxyRequest {
    let method: String
    let path: String
    let headers: [String: String]
}

private struct CollapsHLSFetchResponse {
    let status: Int
    let contentType: String?
    let headers: [String: String]
    let data: Data
}

private enum CollapsHLSProxyError: Error {
    case startTimedOut
    case invalidLocalURL
    case fetchFailed
}
