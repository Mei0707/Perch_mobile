import Foundation

protocol AIInsightServicing {
    func generateInsight(from dashboard: MarketDashboardState) async -> StockInsight
}

struct AIInsightService: AIInsightServicing {
    func generateInsight(from dashboard: MarketDashboardState) async -> StockInsight {
        let leadingMover = dashboard.topMovers.first
        let bullishCount = dashboard.watchlist.filter { $0.sentiment == .bullish }.count
        let sentiment: MarketSentiment = dashboard.dayGainLoss >= 0 ? .bullish : .neutral
        let ticker = leadingMover?.ticker

        let title: String
        let summary: String
        if let leadingMover {
            title = "\(leadingMover.ticker) leads today"
            summary = "\(leadingMover.name) is moving \(String(format: "%.2f", leadingMover.changePercent))% today. Your watchlist has \(bullishCount) bullish names, with technology still carrying most of the momentum."
        } else {
            title = "Market snapshot"
            summary = "Your watchlist is steady. Keep watching portfolio concentration and daily movement before adding risk."
        }

        return StockInsight(
            id: UUID(),
            ticker: ticker,
            title: title,
            summary: summary,
            confidence: 86,
            sentiment: sentiment,
            generatedAt: .now
        )
    }
}
