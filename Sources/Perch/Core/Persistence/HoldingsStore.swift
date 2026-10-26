import Foundation

// Documents/Application Support is backed up and is not purgeable like Caches.
// Failures propagate: a failed write never reports success or replaces in-memory holdings.
final class HoldingsStore {
    let directory: URL
    private var fileURL: URL { directory.appendingPathComponent("holdings-v1.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Perch", isDirectory: true)
    }

    func load(migrating cache: CacheManager) throws -> [Holding] {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let holdings = try JSONDecoder().decode([Holding].self, from: Data(contentsOf: fileURL))
            try Self.validate(holdings)
            return holdings
        }
        let legacy = try cache.loadIfPresent([Holding].self, forKey: "holdings") ?? []
        try save(legacy)
        return legacy
    }

    func save(_ holdings: [Holding]) throws {
        try Self.validate(holdings)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(holdings)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }

    static func validate(_ holdings: [Holding]) throws {
        guard holdings.count <= 50, Set(holdings.map(\.ticker)).count == holdings.count,
              holdings.allSatisfy({ TickerMapper.isValid($0.ticker) && $0.ticker == TickerMapper.symbol(from: $0.ticker)
                  && $0.shares.isFinite && $0.shares > 0 && $0.shares <= 10_000_000
                  && abs($0.shares * 1_000_000 - ($0.shares * 1_000_000).rounded()) < 0.01
                  && $0.averageCost >= 0 && $0.averageCost <= 10_000_000 }) else {
            throw HoldingsError.invalid
        }
    }
}

enum HoldingsError: LocalizedError {
    case invalid
    case duplicateTicker
    var errorDescription: String? {
        switch self {
        case .invalid: return "Use at most fifty holdings with unique valid tickers, positive shares (up to six decimal places), and a nonnegative cost."
        case .duplicateTicker: return "That ticker is already held. Edit its existing position instead of replacing it with another holding."
        }
    }
}
