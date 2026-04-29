import SwiftUI

struct WatchlistView: View {
    @StateObject private var viewModel: WatchlistViewModel

    init(repository: MarketRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: WatchlistViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                List {
                    ForEach(viewModel.filteredStocks) { stock in
                        NavigationLink {
                            StockDetailView(stock: stock)
                        } label: {
                            StockRow(stock: stock)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(.perchBackground)
            .navigationTitle("Watchlist")
            .searchable(text: $viewModel.searchText, prompt: "Search ticker or company")
            .task {
                await viewModel.load()
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SectorChip(title: "All", isSelected: viewModel.selectedSector == nil) {
                    viewModel.selectedSector = nil
                }
                ForEach(StockSector.allCases) { sector in
                    SectorChip(title: sector.rawValue, isSelected: viewModel.selectedSector == sector) {
                        viewModel.selectedSector = sector
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.perchBackground)
    }
}

struct DiscoverView: View {
    @StateObject private var viewModel: WatchlistViewModel

    init(repository: MarketRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: WatchlistViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    searchPrompt
                    sectionHeader("Trending")
                    VStack(spacing: 0) {
                        ForEach(viewModel.filteredStocks.sorted { abs($0.changePercent) > abs($1.changePercent) }) { stock in
                            NavigationLink {
                                StockDetailView(stock: stock)
                            } label: {
                                StockRow(stock: stock)
                            }
                            .buttonStyle(.plain)
                            if stock.id != viewModel.filteredStocks.sorted(by: { abs($0.changePercent) > abs($1.changePercent) }).last?.id {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                    .perchCard(padding: 12)

                    sectionHeader("Sectors")
                    ForEach(StockSector.allCases) { sector in
                        SectorCard(sector: sector, stocks: viewModel.stocks.filter { $0.sector == sector })
                    }
                }
                .padding(20)
            }
            .background(.perchBackground)
            .navigationTitle("Discover")
            .searchable(text: $viewModel.searchText, prompt: "Search any stock")
            .task {
                await viewModel.load()
            }
        }
    }

    private var searchPrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.perchAccent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Find market opportunities")
                    .font(.headline)
                    .foregroundStyle(.perchText)
                Text("Search symbols, compare movers, and scan sector momentum.")
                    .font(.subheadline)
                    .foregroundStyle(.perchMuted)
            }
        }
        .perchCard()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.perchText)
    }
}

private struct SectorChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .perchText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? PerchPalette.accent : .white, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SectorCard: View {
    let sector: StockSector
    let stocks: [Stock]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sector.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(sector.tint)
                .frame(width: 40, height: 40)
                .background(sector.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(sector.rawValue)
                    .font(.headline)
                    .foregroundStyle(.perchText)
                Text(stocks.map(\.ticker).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.perchMuted)
            }
            Spacer()
        }
        .perchCard()
    }
}
