import Foundation
import os.log

public class CollapsHTTPClient {
    private static let logger = OSLog(subsystem: "com.neo.neomovies", category: "CollapsHTTPClient")

    private final class UnsafeURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
        private func handleChallenge(
            _ challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            let method = challenge.protectionSpace.authenticationMethod
            if method == NSURLAuthenticationMethodServerTrust,
               let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }

        func urlSession(
            _ session: URLSession,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            handleChallenge(challenge, completionHandler: completionHandler)
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            handleChallenge(challenge, completionHandler: completionHandler)
        }
    }

    private static let unsafeSession: URLSession = {
        let config = URLSessionConfiguration.default
        let delegate = UnsafeURLSessionDelegate()
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()

    private static func makeRequest(url: String, referer: String?, origin: String?) throws -> URLRequest {
        guard let requestUrl = URL(string: url) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        if let referer = referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        if let origin = origin {
            request.setValue(origin, forHTTPHeaderField: "Origin")
        }
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64)", forHTTPHeaderField: "User-Agent")
        return request
    }

    public static func fetch(
        url: String,
        referer: String? = nil,
        origin: String? = nil
    ) async throws -> String {
        let request = try makeRequest(url: url, referer: referer, origin: origin)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return text
    }

    public static func fetchInsecure(
        url: String,
        referer: String? = nil,
        origin: String? = nil
    ) async throws -> String {
        let request = try makeRequest(url: url, referer: referer, origin: origin)
        let (data, response) = try await unsafeSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            os_log("fetchInsecure bad status=%{public}d url=%{public}s", log: logger, type: .error, status, url)
            throw URLError(.badServerResponse)
        }
        
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return text
    }
}
