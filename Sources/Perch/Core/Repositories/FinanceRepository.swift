import Foundation

protocol MarketRepositoryProtocol {
    func loadDashboard() async throws -> MarketDashboardState
    func loadStocks() async throws -> [Stock]
    func loadStock(ticker: String) async throws -> Stock?
    func loadHoldings() async throws -> [Holding]
    func saveHolding(_ holding: Holding, replacing originalTicker: String?) async throws
    func deleteHolding(ticker: String) async throws
    func replaceHoldings(_ holdings: [Holding]) async throws
    func loadInsights() async throws -> [StockInsight]
    func regenerateInsight() async throws -> StockInsight
}

actor MarketRepository: MarketRepositoryProtocol {
    private var stocks: [Stock] = []
    private var holdings: [Holding] = []
    private var insights: [StockInsight] = []
    private let cache: CacheManager
    private let store: HoldingsStore
    private let aiService: AIInsightServicing
    private let api: APIClient
    private let useBackend: () -> Bool
    private var holdingsError: Error?
    private var lastRefresh: Date = .distantPast
    private var lastBackendMode: Bool?
    private var lastBackendURL: String?
    private var insightSignature = ""
    private var holdingsRevision = 0

    init(cache: CacheManager = CacheManager(), store: HoldingsStore = HoldingsStore(),
         aiService: AIInsightServicing = AIInsightService(), api: APIClient = APIClient(),
         useBackend: @escaping () -> Bool = { AppSettings.baseURL != nil }) {
        self.cache = cache
        self.store = store
        self.aiService = aiService
        self.api = api
        self.useBackend = useBackend
        do { holdings = try store.load(migrating: cache) }
        catch { holdingsError = error }
    }

    func loadDashboard() async throws -> MarketDashboardState {
        try checkHoldings()
        _ = try await loadStocks()
        var dashboard = buildDashboard()
        let signature = dashboard.dataStatus + holdings.description + stocks.map { "\($0.ticker):\($0.price):\($0.quoteAsOf?.timeIntervalSince1970 ?? 0)" }.joined()
        if insights.isEmpty || signature != insightSignature {
            let revision = holdingsRevision
            let quotedStocks = stocks
            let insight = await aiService.generateInsight(from: dashboard)
            guard revision == holdingsRevision, quotedStocks == stocks else { return try await loadDashboard() }
            insights = [insight]
            insightSignature = signature
            dashboard.insights = insights
        }
        return dashboard
    }

    func loadStocks() async throws -> [Stock] {
        try checkHoldings()
        let backend = useBackend()
        let currentURL = AppSettings.baseURL?.absoluteString
        if lastBackendMode != backend || lastBackendURL != currentURL {
            lastRefresh = .distantPast; stocks = []; insights = []
            lastBackendMode = backend; lastBackendURL = currentURL
        }
        if Date().timeIntervalSince(lastRefresh) < 60 && !stocks.isEmpty { return stocks }
        let revision = holdingsRevision
        let heldTickers = Set(holdings.map(\.ticker))
        let extras = MockData.stocks.map(\.ticker).filter { !heldTickers.contains($0) }.prefix(max(0, 50 - heldTickers.count))
        let tickers = Array(heldTickers.union(extras)).sorted()
        if !backend {
            stocks = tickers.map { ticker in MockData.stocks.first { $0.ticker == ticker } ?? Self.unavailableStock(ticker: ticker) }
        } else {
            let saved = cache.load([MarketQuote].self, forKey: "market-quotes-v1") ?? []
            var byTicker = Dictionary(saved.filter { $0.isValid && Date().timeIntervalSince($0.asOf) < 7 * 86_400 }.map { ($0.ticker, $0) }, uniquingKeysWith: { _, new in new })
            // Cached quotes are explicitly stale until the provider refresh succeeds.
            for key in Array(byTicker.keys) { byTicker[key]?.freshness = "stale" }
            do {
                let batch: QuoteBatch = try await api.request(Endpoint(path: "v1/quotes", queryItems: [URLQueryItem(name: "symbols", value: tickers.joined(separator: ","))]))
                for quote in batch.quotes where quote.isValid { byTicker[quote.ticker] = quote }
                cache.save(Array(byTicker.values), forKey: "market-quotes-v1")
            } catch {
                // No sample-price substitution. Missing or expired quotes remain unavailable.
            }
            guard revision == holdingsRevision, currentURL == AppSettings.baseURL?.absoluteString else {
                lastRefresh = .distantPast
                return try await loadStocks()
            }
            stocks = tickers.map { byTicker[$0]?.stock ?? Self.unavailableStock(ticker: $0) }
        }
        lastRefresh = .now
        return stocks
    }

    func loadStock(ticker: String) async throws -> Stock? {
        try await loadStocks().first { $0.ticker == ticker.uppercased() }
    }

    func loadHoldings() async throws -> [Holding] { try checkHoldings(); return holdings }

    func saveHolding(_ holding: Holding, replacing originalTicker: String? = nil) async throws {
        try checkHoldings()
        let normalized = Holding(ticker: TickerMapper.symbol(from: holding.ticker), shares: holding.shares, averageCost: holding.averageCost)
        if let originalTicker, originalTicker.uppercased() != normalized.ticker,
           holdings.contains(where: { $0.ticker == normalized.ticker }) { throw HoldingsError.duplicateTicker }
        var updated = holdings.filter { $0.ticker != normalized.ticker && $0.ticker != originalTicker?.uppercased() }
        updated.append(normalized)
        updated.sort { $0.ticker < $1.ticker }
        try store.save(updated)
        holdings = updated
        holdingsRevision += 1
        lastRefresh = .distantPast
        insights = []
    }

    func deleteHolding(ticker: String) async throws {
        try checkHoldings()
        let updated = holdings.filter { $0.ticker != ticker.uppercased() }
        try store.save(updated)
        holdings = updated
        holdingsRevision += 1
        insights = []
    }

    func replaceHoldings(_ updated: [Holding]) async throws {
        try store.save(updated)
        holdings = updated.sorted { $0.ticker < $1.ticker }
        holdingsRevision += 1
        holdingsError = nil
        lastRefresh = .distantPast
        insights = []
    }

    func loadInsights() async throws -> [StockInsight] { try await loadDashboard().insights }

    func regenerateInsight() async throws -> StockInsight {
        try checkHoldings()
        _ = try await loadStocks()
        let insight = await aiService.generateInsight(from: buildDashboard())
        insights = [insight]
        return insight
    }

    private func checkHoldings() throws { if let holdingsError { throw holdingsError } }

    static func unavailableStock(ticker: String) -> Stock {
        Stock(ticker: ticker, name: MockData.stocks.first { $0.ticker == ticker }?.name ?? ticker,
              exchange: "USD equity", sector: MockData.stocks.first { $0.ticker == ticker }?.sector ?? .unknown,
              price: 0, change: 0, changePercent: 0, open: nil, high: nil, low: nil, previousClose: 0,
              volume: "Unavailable", marketCap: "Unavailable", peRatio: "Unavailable",
              summary: "A valid market quote is unavailable for this symbol.", sentiment: .neutral, chart: [], quoteSource: "Unavailable")
    }

    private func buildDashboard() -> MarketDashboardState {
        let byTicker = Dictionary(uniqueKeysWithValues: stocks.map { ($0.ticker, $0) })
        let complete = holdings.allSatisfy { byTicker[$0.ticker]?.hasPrice == true }
        let portfolioValue = holdings.reduce(Decimal.zero) { result, holding in
            result + (byTicker[holding.ticker].map { holding.marketValue(using: $0) } ?? 0)
        }
        let dayGainLoss = holdings.reduce(Decimal.zero) { result, holding in
            result + (byTicker[holding.ticker].map { holding.dayChange(using: $0) } ?? 0)
        }
        let previousValue = portfolioValue - dayGainLoss
        let dayPercent = previousValue > 0 ? NSDecimalNumber(decimal: dayGainLoss / previousValue).doubleValue * 100 : 0
        let demo = !useBackend()
        let priced = stocks.filter(\.hasPrice)
        let quoteDates = holdings.compactMap { byTicker[$0.ticker]?.quoteAsOf }
        let oldest = quoteDates.min()
        let stale = holdings.contains { byTicker[$0.ticker]?.quoteIsStale == true } || oldest.map { Date().timeIntervalSince($0) > 900 } == true
        let status: String
        if demo { status = "Demo prices · illustrative values" }
        else if !complete { status = "Incomplete quotes · portfolio totals unavailable" }
        else if let oldest { status = "\(stale ? "Stale" : "Recent") quotes · Finnhub · as of \(oldest.formatted(date: .abbreviated, time: .shortened))" }
        else { status = "No priced holdings" }
        return MarketDashboardState(portfolioValue: complete ? portfolioValue : 0, dayGainLoss: complete ? dayGainLoss : 0,
                                    dayGainLossPercent: complete ? dayPercent : 0, watchlist: stocks,
                                    topMovers: priced.sorted { abs($0.changePercent) > abs($1.changePercent) }, holdings: holdings,
                                    indices: demo ? MockData.indices : [], sectors: [], insights: insights,
                                    portfolioTrend: [], dataStatus: status, hasCompleteQuotes: complete, isLoading: false)
    }
}

@MainActor
final class AppContainer: ObservableObject {
    let repository: MarketRepositoryProtocol = MarketRepository()
}
