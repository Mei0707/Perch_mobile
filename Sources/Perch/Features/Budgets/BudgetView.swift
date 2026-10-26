import SwiftUI

struct PortfolioView: View {
    @StateObject private var viewModel: PortfolioViewModel
    @State private var showingHoldingEditor = false
    @State private var editingHolding: Holding?

    init(repository: MarketRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: PortfolioViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    overview
                    Text(viewModel.dataStatus).font(.caption).foregroundStyle(.perchMuted)
                    if let error = viewModel.errorMessage { Text(error).font(.callout).foregroundStyle(.red) }
                    if viewModel.holdings.isEmpty {
                        EmptyStateView(title: "Your portfolio starts here", message: "Add holdings with the plus button. Sample prices are labeled until you connect a backend in Settings.", icon: "briefcase")
                    }
                    Text("Holdings")
                        .font(.headline)
                        .foregroundStyle(.perchText)
                    ForEach(viewModel.holdings) { holding in
                        if let stock = viewModel.stock(for: holding.ticker) {
                            HoldingRow(
                                holding: holding,
                                stock: stock,
                                allocation: viewModel.allocation(for: holding),
                                hasCompleteQuotes: viewModel.hasAllocation,
                                onEdit: {
                                    editingHolding = holding
                                    showingHoldingEditor = true
                                },
                                onDelete: {
                                    Task {
                                        await viewModel.deleteHolding(holding)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(.perchBackground)
            .navigationTitle("Portfolio")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingHolding = nil
                        showingHoldingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add stock to portfolio")
                }
            }
            .sheet(isPresented: $showingHoldingEditor) {
                HoldingEditorView(
                    holding: editingHolding,
                    stocks: viewModel.stocks
                ) { ticker, shares, averageCost, originalTicker in
                    await viewModel.saveHolding(
                        ticker: ticker,
                        shares: shares,
                        averageCost: averageCost,
                        replacing: originalTicker
                    )
                }
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Value")
                        .font(.subheadline)
                        .foregroundStyle(.perchMuted)
                    Text(viewModel.hasCompleteQuotes ? CurrencyFormatter.dollars(viewModel.portfolioValue) : "Unavailable")
                        .font(.largeTitle.monospacedDigit().weight(.bold))
                        .foregroundStyle(.perchText)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Unrealized")
                        .font(.caption)
                        .foregroundStyle(.perchMuted)
                    Text(viewModel.hasCompleteQuotes ? "\(viewModel.totalGainLoss >= 0 ? "+" : "")\(CurrencyFormatter.dollars(viewModel.totalGainLoss))" : "Unavailable")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(viewModel.totalGainLoss >= 0 ? PerchPalette.gain : PerchPalette.loss)
                }
            }

            if viewModel.hasAllocation {
                ForEach(viewModel.holdings.prefix(4)) { holding in
                    if let stock = viewModel.stock(for: holding.ticker) {
                        HStack {
                            Text(holding.ticker)
                                .font(.caption.weight(.bold))
                                .frame(width: 44, alignment: .leading)
                            PerchProgressBar(value: viewModel.allocation(for: holding), tint: stock.sector.tint)
                            Text("\(Int(viewModel.allocation(for: holding) * 100))%")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.perchMuted)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .perchCard()
    }
}

private struct HoldingRow: View {
    let holding: Holding
    let stock: Stock
    let allocation: Double
    let hasCompleteQuotes: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink {
                    StockDetailView(stock: stock)
                } label: {
                    HStack(spacing: 12) {
                        StockLogo(ticker: stock.ticker, size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(stock.ticker)
                                .font(.headline)
                                .foregroundStyle(.perchText)
                            Text("\(holding.shares.formatted(.number.precision(.fractionLength(0...6)))) shares · avg \(CurrencyFormatter.dollars(holding.averageCost))")
                                .font(.caption)
                                .foregroundStyle(.perchMuted)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(stock.hasPrice ? CurrencyFormatter.dollars(holding.marketValue(using: stock)) : "Unavailable")
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.perchText)
                    Text(hasCompleteQuotes ? String(format: "%.2f%%", allocation * 100) : "Allocation unavailable")
                        .font(.caption)
                        .foregroundStyle(.perchMuted)
                }

                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.perchMuted)
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Holding actions")
            }
            Text(stock.freshnessLabel).font(.caption2).foregroundStyle(.perchMuted)
            if stock.hasPrice { PerchProgressBar(value: allocation, tint: stock.sector.tint) }
        }
        .perchCard()
    }
}

private struct HoldingEditorView: View {
    let holding: Holding?
    let stocks: [Stock]
    let onSave: (String, Double, Decimal, String?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var ticker: String
    @State private var shares: String
    @State private var averageCost: String
    @State private var isSaving = false
    @State private var saveError: String?

    init(
        holding: Holding?,
        stocks: [Stock],
        onSave: @escaping (String, Double, Decimal, String?) async -> Bool
    ) {
        self.holding = holding
        self.stocks = stocks
        self.onSave = onSave
        _ticker = State(initialValue: holding?.ticker ?? "")
        _shares = State(initialValue: holding.map { String($0.shares) } ?? "")
        _averageCost = State(initialValue: holding.map { NSDecimalNumber(decimal: $0.averageCost).stringValue } ?? "")
    }

    private var parsedShares: Double? {
        Double(shares.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var parsedAverageCost: Decimal? {
        Decimal(string: averageCost.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canSave: Bool {
        guard TickerMapper.isValid(ticker), let parsedShares, let parsedAverageCost else { return false }
        return parsedShares.isFinite && parsedShares > 0 && parsedShares <= 10_000_000 && parsedAverageCost >= 0 && parsedAverageCost <= 10_000_000
    }

    private var selectedStock: Stock? {
        let symbol = TickerMapper.symbol(from: ticker)
        return stocks.first { $0.ticker == symbol } ?? (TickerMapper.isValid(symbol) ? MarketRepository.unavailableStock(ticker: symbol) : nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Stock") {
                    TextField("Ticker symbol", text: $ticker)
                        .disableAutocorrection(true)
                        .onChange(of: ticker) { newValue in
                            ticker = TickerMapper.symbol(from: newValue)
                        }

                    if !stocks.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(stocks.prefix(8)) { stock in
                                    Button(stock.ticker) {
                                        ticker = stock.ticker
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.perchText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.black.opacity(0.06), in: Capsule())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Position") {
                    TextField("Shares", text: $shares)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Average cost", text: $averageCost)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }

                if let stock = selectedStock,
                   let parsedShares,
                   let parsedAverageCost {
                    Section("Preview") {
                        LabeledContent("Company", value: stock.name)
                        LabeledContent("Last price", value: stock.hasPrice ? CurrencyFormatter.dollars(stock.price) : "Unavailable")
                        Text(stock.freshnessLabel).font(.caption)
                        LabeledContent("Market value", value: stock.hasPrice ? CurrencyFormatter.dollars(stock.price * Decimal(parsedShares)) : "Unavailable")
                        LabeledContent("Cost basis", value: CurrencyFormatter.dollars(parsedAverageCost * Decimal(parsedShares)))
                    }
                }

                if TickerMapper.isValid(ticker), stocks.contains(where: { $0.ticker == TickerMapper.symbol(from: ticker) }) == false {
                    Section {
                        Text("Perch will save your holding. Its value remains unavailable until a market provider returns a valid quote.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { if let saveError { Text(saveError).font(.callout).foregroundStyle(.red).padding() } }
            .navigationTitle(holding == nil ? "Add Stock" : "Edit Holding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        guard let parsedShares, let parsedAverageCost else { return }
                        isSaving = true
                        Task {
                            let saved = await onSave(TickerMapper.symbol(from: ticker), parsedShares, parsedAverageCost, holding?.ticker)
                            isSaving = false
                            if saved { dismiss() } else { saveError = "The holding could not be saved. Check your inputs and try again." }
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }
}
