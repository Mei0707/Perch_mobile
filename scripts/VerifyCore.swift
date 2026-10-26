import Foundation

// Executable smoke checks for machines with Command Line Tools but no XCTest runner.
@main
enum VerifyCore {
    @MainActor
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("perch-verify-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = CacheManager(directory: directory.appendingPathComponent("cache"))
        let store = HoldingsStore(directory: directory.appendingPathComponent("durable"))
        cache.save(MockData.holdings, forKey: "holdings")
        try require(store.load(migrating: cache) == MockData.holdings, "Legacy migration")
        cache.clear()
        try require(store.load(migrating: cache) == MockData.holdings, "Survives cache purge")
        try store.save([])
        try require(store.load(migrating: cache).isEmpty, "Empty portfolio persists")
        let repository = MarketRepository(cache: cache, store: store, useBackend: { false })
        try await repository.saveHolding(Holding(ticker: "snow", shares: 0.123456, averageCost: 100), replacing: nil)
        let saved = try await repository.loadHoldings()
        try require(saved.first?.ticker == "SNOW", "Repository normalizes and saves")
        let stock = try await repository.loadStock(ticker: "SNOW")
        try require(stock?.hasPrice == false && stock?.price == 0, "Unknown symbol has no fake quote")
        let snapshot = try await repository.loadDashboard()
        try require(!snapshot.hasCompleteQuotes, "Incomplete quotes cannot make totals")
        let holding = Holding(ticker: "AAPL", shares: 0.123456, averageCost: 100)
        try require(holding.marketValue(using: MockData.stocks[0]) == Decimal(string: "23.45"), "Position cents rounding")
        try require(holding.dayChange(using: MockData.stocks[0]) == Decimal(string: "0.30"), "Daily contribution rounding")
        try require(TickerMapper.isValid("BRK.B") && !TickerMapper.isValid("../../secret"), "Ticker validation")
        let corruptURL = store.directory.appendingPathComponent("holdings-v1.json")
        try Data("corrupt".utf8).write(to: corruptURL)
        var rejected = false
        do { _ = try store.load(migrating: cache) } catch { rejected = true }
        try require(rejected && String(contentsOf: corruptURL) == "corrupt", "Corrupt data preserved")
        print("10 Swift core smoke checks passed")
        try await VerifyChat.run(directory: directory)
        if let rawURL = ProcessInfo.processInfo.environment["PERCH_VERIFY_API_URL"], let url = URL(string: rawURL) {
            let api = APIClient(baseURL: url)
            let batch: QuoteBatch = try await api.request(Endpoint(path: "v1/quotes", queryItems: [URLQueryItem(name: "symbols", value: "NVDA,AAPL")]))
            try require(batch.quotes.count == 2 && batch.quotes.allSatisfy(\.isValid), "Native quote decoding")
            let holdings = [Holding(ticker: "NVDA", shares: 35, averageCost: 8), Holding(ticker: "AAPL", shares: 65, averageCost: 8)]
            let request = AssistantRequest(holdings: holdings, watchlist: ["NVDA", "AAPL"], messages: [.init(role: "user", content: "Reduce NVDA by 20%")])
            var answer: AssistantAnswer?, sawDraft = false
            try await api.stream(request) { event in
                if event.type == "draft" { sawDraft = true }
                if event.type == "complete" { answer = event.answer }
            }
            try require(sawDraft && answer?.explanation.contains("28.00%") == true, "Native SSE streaming and completion")
            if let answer { try await api.feedback(answerID: answer.id, rating: "helpful") }
            try require(answer != nil, "Native feedback request")
            print("3 Swift-to-Node HTTP and streaming checks passed")
        }
    }

    private static func require(_ condition: @autoclosure () throws -> Bool, _ label: String) throws {
        if try !condition() { throw NSError(domain: "PerchVerification", code: 1, userInfo: [NSLocalizedDescriptionKey: label]) }
    }
}
