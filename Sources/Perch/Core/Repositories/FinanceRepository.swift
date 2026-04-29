import Foundation

protocol MarketRepositoryProtocol {
    func loadDashboard() async throws -> MarketDashboardState
    func loadStocks() async throws -> [Stock]
    func loadStock(ticker: String) async throws -> Stock?
    func loadHoldings() async throws -> [Holding]
    func saveHolding(_ holding: Holding, replacing originalTicker: String?) async throws
    func deleteHolding(ticker: String) async throws
    func loadInsights() async throws -> [StockInsight]
    func regenerateInsight() async throws -> StockInsight
}

actor MarketRepository: MarketRepositoryProtocol {
    private var stocks: [Stock]
    private var holdings: [Holding]
    private var insights: [StockInsight]
    private let cache: CacheManager
    private let aiService: AIInsightServicing

    init(
        cache: CacheManager = CacheManager(),
        aiService: AIInsightServicing = AIInsightService()
    ) {
        self.cache = cache
        self.aiService = aiService
        self.stocks = cache.load([Stock].self, forKey: "stocks") ?? MockData.stocks
        self.holdings = cache.load([Holding].self, forKey: "holdings") ?? MockData.holdings
        self.insights = cache.load([StockInsight].self, forKey: "stock-insights") ?? []
    }

    func loadDashboard() async throws -> MarketDashboardState {
        let dashboard = buildDashboard()
        if dashboard.insights.isEmpty {
            let insight = await aiService.generateInsight(from: dashboard)
            insights = [insight]
            cache.save(insights, forKey: "stock-insights")
            return buildDashboard()
        }
        return dashboard
    }

    func loadStocks() async throws -> [Stock] {
        stocks.sorted { $0.ticker < $1.ticker }
    }

    func loadStock(ticker: String) async throws -> Stock? {
        stocks.first { $0.ticker == ticker.uppercased() }
    }

    func loadHoldings() async throws -> [Holding] {
        holdings
    }

    func saveHolding(_ holding: Holding, replacing originalTicker: String? = nil) async throws {
        let normalizedHolding = Holding(
            ticker: holding.ticker.uppercased(),
            shares: holding.shares,
            averageCost: holding.averageCost
        )

        if stocks.contains(where: { $0.ticker == normalizedHolding.ticker }) == false {
            stocks.append(MockData.generatedStock(ticker: normalizedHolding.ticker))
            stocks.sort { $0.ticker < $1.ticker }
            cache.save(stocks, forKey: "stocks")
        }

        if let originalTicker, originalTicker.uppercased() != normalizedHolding.ticker {
            holdings.removeAll { $0.ticker == originalTicker.uppercased() }
        }

        if let index = holdings.firstIndex(where: { $0.ticker == normalizedHolding.ticker }) {
            holdings[index] = normalizedHolding
        } else {
            holdings.append(normalizedHolding)
        }

        holdings.sort { $0.ticker < $1.ticker }
        cache.save(holdings, forKey: "holdings")
    }

    func deleteHolding(ticker: String) async throws {
        holdings.removeAll { $0.ticker == ticker.uppercased() }
        cache.save(holdings, forKey: "holdings")
    }

    func loadInsights() async throws -> [StockInsight] {
        if insights.isEmpty {
            _ = try await regenerateInsight()
        }
        return insights
    }

    func regenerateInsight() async throws -> StockInsight {
        let insight = await aiService.generateInsight(from: buildDashboard())
        insights.insert(insight, at: 0)
        insights = Array(insights.prefix(6))
        cache.save(insights, forKey: "stock-insights")
        return insight
    }

    private func buildDashboard() -> MarketDashboardState {
        let stockByTicker = Dictionary(uniqueKeysWithValues: stocks.map { ($0.ticker, $0) })
        let portfolioValue = holdings.reduce(Decimal.zero) { partial, holding in
            guard let stock = stockByTicker[holding.ticker] else { return partial }
            return partial + holding.marketValue(using: stock)
        }
        let dayGainLoss = holdings.reduce(Decimal.zero) { partial, holding in
            guard let stock = stockByTicker[holding.ticker] else { return partial }
            return partial + (stock.change * Decimal(holding.shares))
        }
        let previousValue = max(portfolioValue - dayGainLoss, 1)
        let dayGainLossPercent = (dayGainLoss as NSDecimalNumber).doubleValue / (previousValue as NSDecimalNumber).doubleValue * 100

        let portfolioTrend = MockData.stocks.first?.chart.enumerated().map { index, _ in
            holdings.reduce(0) { partial, holding in
                guard let stock = stockByTicker[holding.ticker] else { return partial }
                let point = stock.chart[min(index, stock.chart.count - 1)]
                return partial + point * holding.shares
            }
        } ?? []

        return MarketDashboardState(
            portfolioValue: portfolioValue,
            dayGainLoss: dayGainLoss,
            dayGainLossPercent: dayGainLossPercent,
            watchlist: stocks,
            topMovers: stocks.sorted { abs($0.changePercent) > abs($1.changePercent) },
            holdings: holdings,
            indices: MockData.indices,
            sectors: MockData.sectors,
            insights: insights,
            portfolioTrend: portfolioTrend,
            isLoading: false
        )
    }
}

@MainActor
final class AppContainer: ObservableObject {
    let repository: MarketRepositoryProtocol = MarketRepository()
}
