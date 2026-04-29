import Foundation

enum MarketSentiment: String, Codable, CaseIterable, Identifiable {
    case bullish = "Bullish"
    case neutral = "Neutral"
    case bearish = "Bearish"

    var id: String { rawValue }
}

enum StockSector: String, Codable, CaseIterable, Identifiable {
    case technology = "Technology"
    case consumer = "Consumer"
    case communication = "Communication"
    case financials = "Financials"
    case healthcare = "Healthcare"

    var id: String { rawValue }
}

struct Stock: Identifiable, Codable, Equatable {
    var id: String { ticker }
    let ticker: String
    let name: String
    let exchange: String
    let sector: StockSector
    let price: Decimal
    let change: Decimal
    let changePercent: Double
    let open: Decimal
    let high: Decimal
    let low: Decimal
    let previousClose: Decimal
    let volume: String
    let marketCap: String
    let peRatio: String
    let summary: String
    let sentiment: MarketSentiment
    let chart: [Double]

    var isUp: Bool { change >= 0 }
}

struct Holding: Identifiable, Codable, Equatable {
    var id: String { ticker }
    let ticker: String
    let shares: Double
    let averageCost: Decimal

    func marketValue(using stock: Stock) -> Decimal {
        stock.price * Decimal(shares)
    }

    func gainLoss(using stock: Stock) -> Decimal {
        marketValue(using: stock) - (averageCost * Decimal(shares))
    }
}

struct MarketIndex: Identifiable, Codable, Equatable {
    var id: String { name }
    let name: String
    let value: String
    let changePercent: Double

    var isUp: Bool { changePercent >= 0 }
}

struct SectorSummary: Identifiable, Codable, Equatable {
    var id: StockSector { sector }
    let sector: StockSector
    let tickers: [String]
    let changePercent: Double
}

struct StockInsight: Identifiable, Codable, Equatable {
    var id: UUID
    let ticker: String?
    let title: String
    let summary: String
    let confidence: Int
    let sentiment: MarketSentiment
    let generatedAt: Date
}

struct MarketDashboardState: Codable, Equatable {
    var portfolioValue: Decimal
    var dayGainLoss: Decimal
    var dayGainLossPercent: Double
    var watchlist: [Stock]
    var topMovers: [Stock]
    var holdings: [Holding]
    var indices: [MarketIndex]
    var sectors: [SectorSummary]
    var insights: [StockInsight]
    var portfolioTrend: [Double]
    var isLoading: Bool

    static let empty = MarketDashboardState(
        portfolioValue: 0,
        dayGainLoss: 0,
        dayGainLossPercent: 0,
        watchlist: [],
        topMovers: [],
        holdings: [],
        indices: [],
        sectors: [],
        insights: [],
        portfolioTrend: [],
        isLoading: false
    )
}
