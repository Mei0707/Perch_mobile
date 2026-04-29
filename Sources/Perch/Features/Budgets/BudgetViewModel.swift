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
        guard let stock = stock(for: holding.ticker), portfolioValue > 0 else { return 0 }
        return (holding.marketValue(using: stock) as NSDecimalNumber).doubleValue / (portfolioValue as NSDecimalNumber).doubleValue
    }

    func saveHolding(ticker: String, shares: Double, averageCost: Decimal, replacing originalTicker: String?) async {
        do {
            try await repository.saveHolding(
                Holding(ticker: ticker, shares: shares, averageCost: averageCost),
                replacing: originalTicker
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
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
