import Foundation

struct InsightResponseParser {
    struct Response: Decodable {
        let ticker: String?
        let title: String
        let summary: String
        let confidence: Int
        let sentiment: MarketSentiment
    }

    func parse(_ data: Data) throws -> StockInsight {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return StockInsight(
            id: UUID(),
            ticker: response.ticker,
            title: response.title,
            summary: response.summary,
            confidence: response.confidence,
            sentiment: response.sentiment,
            generatedAt: .now
        )
    }
}
