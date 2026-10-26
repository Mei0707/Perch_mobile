import Foundation

enum NetworkError: LocalizedError, Equatable {
    case notConfigured
    case configurationFailed
    case interrupted
    case invalidURL
    case invalidResponse
    case serverStatus(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Connect your Perch backend in Settings to use market quotes and Ask Perch."
        case .configurationFailed:
            return "Perch could not securely save the backend credential."
        case .interrupted:
            return "The response was interrupted. Please retry."
        case .invalidURL:
            return "The request URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .serverStatus(let code):
            switch code {
            case 401, 403: return "Your backend token was rejected. Update it in Settings and test the saved connection."
            case 429: return "The demo request limit has been reached. Wait before retrying; the daily budget may reset tomorrow."
            case 502, 503, 504: return "The backend is temporarily unavailable. Please retry shortly."
            default: return "The server returned status code \(code)."
            }
        case .decodingFailed:
            return "Perch could not read the server response."
        }
    }
}
