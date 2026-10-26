import XCTest
@testable import Perch

final class PerchTests: XCTestCase {
    private var directories: [URL] = []

    override func tearDownWithError() throws {
        for directory in directories { try FileManager.default.removeItem(at: directory) }
    }

    func testTickerMapperUsesSameASCIIContractAsBackend() {
        XCTAssertEqual(TickerMapper.symbol(from: " aapl "), "AAPL")
        XCTAssertTrue(TickerMapper.isValid("BRK.B"))
        for symbol in ["../secret", "", "123", "éA", "AAAAAAAAA"] { XCTAssertFalse(TickerMapper.isValid(symbol)) }
    }

    func testHoldingValuesRoundEachPositionToCents() {
        let stock = MockData.stocks[0]
        let holding = Holding(ticker: "AAPL", shares: 0.123456, averageCost: 100)
        XCTAssertEqual(holding.marketValue(using: stock), Decimal(string: "23.45"))
        XCTAssertEqual(holding.dayChange(using: stock), Decimal(string: "0.30"))
    }

    func testDashboardHasLabeledDemoDataAndNoInventedHistory() async throws {
        let repository = try makeRepository(holdings: MockData.holdings)
        let dashboard = try await repository.loadDashboard()
        XCTAssertGreaterThan(dashboard.portfolioValue, 0)
        XCTAssertTrue(dashboard.dataStatus.contains("Demo"))
        XCTAssertFalse(dashboard.watchlist.isEmpty)
        XCTAssertTrue(dashboard.portfolioTrend.isEmpty)
    }

    func testNewPortfolioStartsEmpty() async throws {
        let repository = try makeRepository()
        let holdings = try await repository.loadHoldings()
        XCTAssertTrue(holdings.isEmpty)
    }

    func testHoldingsSurviveCachePurgeAndRepositoryRecreation() async throws {
        let directory = temporaryDirectory()
        let cache = CacheManager(directory: directory.appendingPathComponent("cache"))
        let store = HoldingsStore(directory: directory.appendingPathComponent("durable"))
        let first = MarketRepository(cache: cache, store: store, aiService: StubAI(), useBackend: { false })
        try await first.saveHolding(Holding(ticker: "snow", shares: 2.123456, averageCost: 150), replacing: nil)
        cache.clear()
        let second = MarketRepository(cache: cache, store: store, aiService: StubAI(), useBackend: { false })
        let holdings = try await second.loadHoldings()
        XCTAssertEqual(holdings, [Holding(ticker: "SNOW", shares: 2.123456, averageCost: 150)])
        let stock = try await second.loadStock(ticker: "SNOW")
        XCTAssertEqual(stock?.hasPrice, false)
        XCTAssertEqual(stock?.price, 0)
        let dashboard = try await second.loadDashboard()
        XCTAssertFalse(dashboard.hasCompleteQuotes)
    }

    func testLegacyCacheMigratesOnlyOnceAndDeletionPersists() async throws {
        let directory = temporaryDirectory()
        let cache = CacheManager(directory: directory.appendingPathComponent("cache"))
        cache.save(MockData.holdings, forKey: "holdings")
        let store = HoldingsStore(directory: directory.appendingPathComponent("durable"))
        XCTAssertEqual(try store.load(migrating: cache), MockData.holdings)
        try store.save([])
        XCTAssertEqual(try store.load(migrating: cache), [])
    }

    func testCorruptedDurableStoreIsNotReplacedByLegacyCache() throws {
        let directory = temporaryDirectory()
        let store = HoldingsStore(directory: directory)
        let url = directory.appendingPathComponent("holdings-v1.json")
        try Data("corrupt-user-data".utf8).write(to: url)
        XCTAssertThrowsError(try store.load(migrating: CacheManager(directory: directory)))
        XCTAssertEqual(try String(contentsOf: url), "corrupt-user-data")
    }

    func testInvalidHoldingsAndDuplicateSymbolsCannotBeSaved() throws {
        let store = HoldingsStore(directory: temporaryDirectory())
        for shares in [0.0, -1, .infinity, 0.1234567] {
            XCTAssertThrowsError(try store.save([Holding(ticker: "AAPL", shares: shares, averageCost: 10)]))
        }
        XCTAssertThrowsError(try store.save([MockData.holdings[0], MockData.holdings[0]]))
    }

    func testRepositoryEditsAndDeletesDurably() async throws {
        let repository = try makeRepository(holdings: [MockData.holdings[0]])
        try await repository.saveHolding(Holding(ticker: "MSFT", shares: 4, averageCost: 100), replacing: "AAPL")
        let holdings = try await repository.loadHoldings()
        XCTAssertEqual(holdings.map(\.ticker), ["MSFT"])
        try await repository.deleteHolding(ticker: "MSFT")
        let empty = try await repository.loadHoldings()
        XCTAssertTrue(empty.isEmpty)
    }

    func testQuoteDecoderAcceptsProviderFractionalTimestampAndRejectsZeroPrice() throws {
        let json = """
        {"ticker":"AAPL","name":"Apple","sector":"Technology","price":10,"previousClose":12,
        "asOf":"2025-01-02T15:00:00.123Z","source":"Finnhub","freshness":"stale"}
        """
        let quote = try APIClient.decoder().decode(MarketQuote.self, from: Data(json.utf8))
        XCTAssertTrue(quote.isValid)
        XCTAssertFalse(quote.stock.isDemo)
        XCTAssertTrue(quote.stock.freshnessLabel.contains("Stale"))
        XCTAssertTrue(quote.stock.chart.isEmpty)
        let invalid = try APIClient.decoder().decode(MarketQuote.self, from: Data(json.replacingOccurrences(of: "\"price\":10", with: "\"price\":0").utf8))
        XCTAssertFalse(invalid.isValid)
    }

    func testPromptIncludesOnlyCompletedTurnsAndBoundsContext() {
        let turns = (0..<30).map { ConversationTurn(role: $0 % 2 == 0 ? "user" : "assistant", content: String(repeating: "x", count: 2000)) }
            + [ConversationTurn(role: "assistant", content: "unverified", isComplete: false)]
        let request = PromptBuilder.request(holdings: [], stocks: [], turns: turns)
        XCTAssertEqual(request.messages.count, 12)
        XCTAssertTrue(request.messages.allSatisfy { $0.content.count <= 1600 })
        XCTAssertFalse(request.messages.contains { $0.content == "unverified" })
    }

    private func makeRepository(holdings: [Holding] = []) throws -> MarketRepository {
        let directory = temporaryDirectory()
        let store = HoldingsStore(directory: directory.appendingPathComponent("durable"))
        try store.save(holdings)
        return MarketRepository(cache: CacheManager(directory: directory.appendingPathComponent("cache")), store: store,
                                aiService: StubAI(), useBackend: { false })
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        directories.append(directory)
        return directory
    }
}

private struct StubAI: AIInsightServicing {
    func generateInsight(from dashboard: MarketDashboardState) async -> StockInsight {
        StockInsight(id: UUID(), ticker: nil, title: "Test snapshot", summary: "Calculated", dataStatus: "Test", sentiment: .neutral, generatedAt: .now)
    }
}
