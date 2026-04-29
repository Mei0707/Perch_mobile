import Foundation

struct Endpoint {
    var path: String
    var method: String = "GET"
    var queryItems: [URLQueryItem] = []
    var body: Data?

    func makeURLRequest(baseURL: URL) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

extension Endpoint {
    static let stocks = Endpoint(path: "stocks")
    static let quote = Endpoint(path: "quote")
    static let marketSummary = Endpoint(path: "market/summary")
    static let holdings = Endpoint(path: "portfolio/holdings")
    static let generateInsights = Endpoint(path: "market/insights/generate", method: "POST")
}
