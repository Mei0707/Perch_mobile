import Foundation

struct AnswerFact: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let display: String
}

struct AnswerSource: Codable, Equatable {
    let ticker: String
    let source: String
    let asOf: Date
    let freshness: String
}

struct AssistantAnswer: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let explanation: String
    let mode: String
    let facts: [AnswerFact]
    let factIDs: [String]
    let limitations: [String]
    let sources: [AnswerSource]
    let coverage: String
    let freshness: String
    let asOf: Date?
    let toolCalls: [String]
    let latencyMs: Int

    var statusLabel: String {
        if mode == "fallback" { return "Calculated fallback" }
        if coverage != "complete" { return "Incomplete quotes" }
        return freshness == "fresh" ? "Sourced quotes" : "Stale quotes"
    }
}

struct ConversationTurn: Codable, Equatable, Identifiable {
    var id = UUID()
    let role: String
    var content: String
    var answer: AssistantAnswer?
    var rating: String?
    var isComplete = true
}

struct AssistantRequest: Encodable {
    let holdings: [Holding]
    let watchlist: [String]
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

struct AssistantEvent: Decodable {
    let type: String
    let name: String?
    let message: String?
    let text: String?
    let answer: AssistantAnswer?
}

struct QuoteBatch: Decodable {
    let quotes: [MarketQuote]
    let unavailable: [String]
}

struct MarketQuote: Codable {
    let ticker: String
    let name: String
    let sector: String
    let price: Decimal
    let previousClose: Decimal
    let open: Decimal?
    let high: Decimal?
    let low: Decimal?
    let asOf: Date
    let source: String
    var freshness: String

    var isValid: Bool {
        price > 0 && price <= 10_000_000 && previousClose > 0 && previousClose <= 10_000_000
            && asOf.timeIntervalSince1970 > 0 && asOf <= Date().addingTimeInterval(60) && source == "Finnhub"
    }

    var stock: Stock {
        let change = price - previousClose
        let changePercent = NSDecimalNumber(decimal: change / previousClose).doubleValue * 100
        return Stock(ticker: ticker, name: name, exchange: "USD equity", sector: StockSector(rawValue: sector) ?? .unknown,
                     price: price, change: change, changePercent: changePercent,
                     open: open.flatMap { $0 > 0 ? $0 : nil }, high: high.flatMap { $0 > 0 ? $0 : nil }, low: low.flatMap { $0 > 0 ? $0 : nil }, previousClose: previousClose,
                     volume: "Unavailable", marketCap: "Unavailable", peRatio: "Unavailable",
                     summary: "Company fundamentals and news are not supplied by this quote endpoint.",
                     sentiment: .neutral, chart: [], quoteSource: source, quoteAsOf: asOf,
                     quoteIsStale: freshness == "stale")
    }
}
