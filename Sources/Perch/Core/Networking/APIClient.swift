import Foundation

protocol AssistantClient {
    func stream(_ input: AssistantRequest, onEvent: @escaping (AssistantEvent) async -> Void) async throws
    func feedback(answerID: String, rating: String) async throws
}

final class APIClient: AssistantClient {
    private let configuredURL: URL?
    private let session: URLSession

    init(baseURL: URL? = nil, session: URLSession = .shared) {
        self.configuredURL = baseURL
        self.session = session
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { value in
            let raw = try value.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else {
                throw DecodingError.dataCorrupted(.init(codingPath: value.codingPath, debugDescription: "Invalid source timestamp"))
            }
            return date
        }
        return decoder
    }

    private func makeRequest(_ endpoint: Endpoint) throws -> URLRequest {
        guard let baseURL = configuredURL ?? AppSettings.baseURL else { throw NetworkError.notConfigured }
        var request = try endpoint.makeURLRequest(baseURL: baseURL)
        request.timeoutInterval = 100
        if let token = AppSettings.backendToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let (data, response) = try await session.data(for: makeRequest(endpoint))
        try validate(response)
        do { return try Self.decoder().decode(T.self, from: data) }
        catch { throw NetworkError.decodingFailed }
    }

    func stream(_ input: AssistantRequest, onEvent: @escaping (AssistantEvent) async -> Void) async throws {
        let endpoint = Endpoint(path: "v1/ask", method: "POST", body: try JSONEncoder().encode(input))
        var request = try makeRequest(endpoint)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        try validate(response)
        guard (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.contains("text/event-stream") == true else { throw NetworkError.invalidResponse }
        var payload = "", completed = false
        var lineBytes = Data()
        // AsyncBytes.lines may omit empty lines on supported OS versions. SSE uses
        // empty lines as frame separators, so preserve them in the byte stream.
        for try await byte in bytes {
            try Task.checkCancellation()
            if byte != 10 {
                lineBytes.append(byte)
                guard lineBytes.count < 1_000_000 else { throw NetworkError.invalidResponse }
                continue
            }
            if lineBytes.last == 13 { lineBytes.removeLast() }
            guard let line = String(data: lineBytes, encoding: .utf8) else { throw NetworkError.decodingFailed }
            lineBytes.removeAll(keepingCapacity: true)
            if line.isEmpty {
                if !payload.isEmpty {
                    let event = try Self.decoder().decode(AssistantEvent.self, from: Data(payload.utf8))
                    if event.type == "error" { throw NetworkError.interrupted }
                    if event.type == "complete" {
                        guard let answer = event.answer else { throw NetworkError.invalidResponse }
                        try InsightResponseParser().validate(answer)
                        completed = true
                    }
                    await onEvent(event)
                    payload = ""
                }
            } else if line.hasPrefix("data:") {
                if !payload.isEmpty { payload += "\n" }
                payload += line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                guard payload.utf8.count < 1_000_000 else { throw NetworkError.invalidResponse }
            }
        }
        guard completed else { throw NetworkError.interrupted }
    }

    func connectionStatus() async throws -> BackendStatus {
        try await request(Endpoint(path: "v1/status"))
    }

    func feedback(answerID: String, rating: String) async throws {
        struct Feedback: Encodable { let answerID: String; let rating: String }
        struct Receipt: Decodable { let saved: Bool }
        let _: Receipt = try await request(Endpoint(path: "v1/feedback", method: "POST",
                                                    body: JSONEncoder().encode(Feedback(answerID: answerID, rating: rating))))
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard 200..<300 ~= response.statusCode else { throw NetworkError.serverStatus(response.statusCode) }
    }
}
