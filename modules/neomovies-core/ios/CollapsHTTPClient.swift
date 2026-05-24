import Foundation

public class CollapsHTTPClient {
    public static func fetch(
        url: String,
        referer: String? = nil,
        origin: String? = nil
    ) async throws -> String {
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
}
