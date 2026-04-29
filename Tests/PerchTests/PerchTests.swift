import XCTest
@testable import Perch

final class PerchTests: XCTestCase {
    func testTickerMapperNormalizesSymbols() {
        XCTAssertEqual(TickerMapper.symbol(from: " aapl "), "AAPL")
    }

    func testHoldingMarketValueUsesLatestPrice() {
        let stock = MockData.stocks[0]
        let holding = Holding(ticker: stock.ticker, shares: 2, averageCost: 100)

        XCTAssertEqual(holding.marketValue(using: stock), stock.price * 2)
    }

    func testDashboardLoadsMarketData() async throws {
        let repository = MarketRepository(cache: CacheManager(directory: temporaryDirectory()))
        let dashboard = try await repository.loadDashboard()

        XCTAssertGreaterThan(dashboard.portfolioValue, 0)
        XCTAssertFalse(dashboard.watchlist.isEmpty)
        XCTAssertFalse(dashboard.topMovers.isEmpty)
        XCTAssertFalse(dashboard.insights.isEmpty)
    }

    func testRepositoryCanSaveAndDeleteHolding() async throws {
        let repository = MarketRepository(cache: CacheManager(directory: temporaryDirectory()))

        try await repository.saveHolding(
            Holding(ticker: "NFLX", shares: 3, averageCost: 600),
            replacing: nil
        )
        var holdings = try await repository.loadHoldings()
        XCTAssertEqual(holdings.first(where: { $0.ticker == "NFLX" })?.shares, 3)

        try await repository.saveHolding(
            Holding(ticker: "NFLX", shares: 4, averageCost: 610),
            replacing: "NFLX"
        )
        holdings = try await repository.loadHoldings()
        XCTAssertEqual(holdings.first(where: { $0.ticker == "NFLX" })?.shares, 4)

        try await repository.deleteHolding(ticker: "NFLX")
        holdings = try await repository.loadHoldings()
        XCTAssertNil(holdings.first(where: { $0.ticker == "NFLX" }))
    }

    func testRepositoryCanAddAnyTickerWithGeneratedQuote() async throws {
        let repository = MarketRepository(cache: CacheManager(directory: temporaryDirectory()))

        try await repository.saveHolding(
            Holding(ticker: "snow", shares: 2, averageCost: 150),
            replacing: nil
        )

        let stocks = try await repository.loadStocks()
        let holdings = try await repository.loadHoldings()

        XCTAssertNotNil(stocks.first(where: { $0.ticker == "SNOW" }))
        XCTAssertEqual(holdings.first(where: { $0.ticker == "SNOW" })?.shares, 2)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
