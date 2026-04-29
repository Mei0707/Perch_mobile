import Foundation

enum NetworkError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case serverStatus(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .serverStatus(let code):
            return "The server returned status code \(code)."
        case .decodingFailed:
            return "Perch could not read the server response."
        }
    }
}
