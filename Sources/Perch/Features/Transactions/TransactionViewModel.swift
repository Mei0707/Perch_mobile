import Foundation

@MainActor
final class WatchlistViewModel: ObservableObject {
    @Published private(set) var stocks: [Stock] = []
    @Published var searchText = ""
    @Published var selectedSector: StockSector?
    @Published var errorMessage: String?

    private let repository: MarketRepositoryProtocol

    init(repository: MarketRepositoryProtocol) {
        self.repository = repository
    }

    var filteredStocks: [Stock] {
        stocks.filter { stock in
            let matchesSearch = searchText.isEmpty
                || stock.ticker.localizedCaseInsensitiveContains(searchText)
                || stock.name.localizedCaseInsensitiveContains(searchText)
            let matchesSector = selectedSector == nil || stock.sector == selectedSector
            return matchesSearch && matchesSector
        }
    }

    func load() async {
        do {
            stocks = try await repository.loadStocks()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
