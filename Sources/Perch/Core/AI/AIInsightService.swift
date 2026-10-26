import Foundation

protocol AIInsightServicing {
    func generateInsight(from dashboard: MarketDashboardState) async -> StockInsight
}

struct AIInsightService: AIInsightServicing {
    let api = APIClient()

    func generateInsight(from dashboard: MarketDashboardState) async -> StockInsight {
        if AppSettings.baseURL != nil {
            do {
                let request = AssistantRequest(holdings: dashboard.holdings, watchlist: dashboard.watchlist.map(\.ticker),
                                               messages: [.init(role: "user", content: "Explain my portfolio movement and concentration using current quotes.")])
                let answer: AssistantAnswer = try await api.request(Endpoint(path: "v1/insights", method: "POST", body: JSONEncoder().encode(request)))
                try InsightResponseParser().validate(answer)
                return StockInsight(id: UUID(), ticker: nil, title: answer.title,
                                    summary: answer.explanation + "\n" + answer.limitations.joined(separator: " "),
                                    dataStatus: answer.statusLabel, sources: answer.sources, sentiment: .neutral, generatedAt: .now)
            } catch { /* Local fallback is always marked as calculated or illustrative. */ }
        }
        let summary: String
        if !dashboard.hasCompleteQuotes { summary = "Some holdings have no valid quote. Refresh market data before evaluating portfolio movement or allocation." }
        else if dashboard.holdings.isEmpty { summary = "Add your holdings in Portfolio to see calculated movement and allocation." }
        else { summary = "Portfolio value: \(CurrencyFormatter.dollars(dashboard.portfolioValue)). Daily price contribution: \(CurrencyFormatter.dollars(dashboard.dayGainLoss)) (\(String(format: "%.2f", dashboard.dayGainLossPercent))%). Price changes alone do not explain news or business causes." }
        return StockInsight(id: UUID(), ticker: nil, title: "Calculated portfolio snapshot", summary: summary,
                            dataStatus: "Rule-based · \(dashboard.dataStatus)", sentiment: .neutral, generatedAt: .now)
    }
}
