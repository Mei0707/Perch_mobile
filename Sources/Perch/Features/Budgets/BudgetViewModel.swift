import Foundation

@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published private(set) var holdings: [Holding] = []
    @Published private(set) var stocks: [Stock] = []
    @Published var errorMessage: String?

    private let repository: MarketRepositoryProtocol

    init(repository: MarketRepositoryProtocol) {
        self.repository = repository
    }

    var hasCompleteQuotes: Bool { holdings.allSatisfy { stock(for: $0.ticker)?.hasPrice == true } }
    var hasAllocation: Bool { hasCompleteQuotes && portfolioValue > 0 }
    var dataStatus: String {
        if !hasCompleteQuotes { return "Incomplete quotes · totals unavailable" }
        if stocks.contains(where: \.isDemo) { return "Demo prices · illustrative values" }
        return "Sourced quotes · see timestamps on each holding"
    }

    var portfolioValue: Decimal {
        holdings.reduce(Decimal.zero) { partial, holding in
            guard let stock = stock(for: holding.ticker) else { return partial }
            return partial + holding.marketValue(using: stock)
        }
    }

    var totalGainLoss: Decimal {
        holdings.reduce(Decimal.zero) { partial, holding in
            guard let stock = stock(for: holding.ticker) else { return partial }
            return partial + holding.gainLoss(using: stock)
        }
    }

    func stock(for ticker: String) -> Stock? {
        stocks.first { $0.ticker == ticker }
    }

    func allocation(for holding: Holding) -> Double {
        guard hasCompleteQuotes, let stock = stock(for: holding.ticker), portfolioValue > 0 else { return 0 }
        return (holding.marketValue(using: stock) as NSDecimalNumber).doubleValue / (portfolioValue as NSDecimalNumber).doubleValue
    }

    func saveHolding(ticker: String, shares: Double, averageCost: Decimal, replacing originalTicker: String?) async -> Bool {
        do {
            try await repository.saveHolding(
                Holding(ticker: ticker, shares: shares, averageCost: averageCost),
                replacing: originalTicker
            )
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteHolding(_ holding: Holding) async {
        do {
            try await repository.deleteHolding(ticker: holding.ticker)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load() async {
        do {
            holdings = try await repository.loadHoldings()
            stocks = try await repository.loadStocks()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
