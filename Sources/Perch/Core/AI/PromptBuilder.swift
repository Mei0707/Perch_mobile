import Foundation

enum PromptBuilder {
    static func marketPrompt(dashboard: MarketDashboardState) -> String {
        let movers = dashboard.topMovers.prefix(3)
            .map { "\($0.ticker): \($0.changePercent)%" }
            .joined(separator: ", ")
        let holdings = dashboard.holdings
            .map { "\($0.ticker): \($0.shares) shares" }
            .joined(separator: ", ")

        return """
        Generate a concise stock-market insight.
        Portfolio value: \(CurrencyFormatter.dollars(dashboard.portfolioValue)).
        Day change: \(CurrencyFormatter.dollars(dashboard.dayGainLoss)) (\(String(format: "%.2f", dashboard.dayGainLossPercent))%).
        Top movers: \(movers).
        Holdings: \(holdings).
        Return JSON with ticker, title, summary, confidence, and sentiment.
        """
    }
}
