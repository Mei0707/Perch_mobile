import Foundation

final class CacheManager {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        let baseDirectory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.directory = baseDirectory.appending(path: "PerchCache", directoryHint: .isDirectory)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func save<T: Encodable>(_ value: T, forKey key: String) {
        let url = directory.appending(path: "\(key).json")
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        let url = directory.appending(path: "\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
