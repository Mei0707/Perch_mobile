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
                    Text("Holdings")
                        .font(.headline)
                        .foregroundStyle(.perchText)
                    ForEach(viewModel.holdings) { holding in
                        if let stock = viewModel.stock(for: holding.ticker) {
                            HoldingRow(
                                holding: holding,
                                stock: stock,
                                allocation: viewModel.allocation(for: holding),
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
                    Text(CurrencyFormatter.dollars(viewModel.portfolioValue))
                        .font(.largeTitle.monospacedDigit().weight(.bold))
                        .foregroundStyle(.perchText)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("All Time")
                        .font(.caption)
                        .foregroundStyle(.perchMuted)
                    Text("\(viewModel.totalGainLoss >= 0 ? "+" : "")\(CurrencyFormatter.dollars(viewModel.totalGainLoss))")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(viewModel.totalGainLoss >= 0 ? PerchPalette.gain : PerchPalette.loss)
                }
            }

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
        .perchCard()
    }
}

private struct HoldingRow: View {
    let holding: Holding
    let stock: Stock
    let allocation: Double
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
                            Text("\(String(format: "%.1f", holding.shares)) shares · avg \(CurrencyFormatter.dollars(holding.averageCost))")
                                .font(.caption)
                                .foregroundStyle(.perchMuted)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(CurrencyFormatter.dollars(holding.marketValue(using: stock)))
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.perchText)
                    Text("\(allocation * 100, specifier: "%.0f")%")
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
            PerchProgressBar(value: allocation, tint: stock.sector.tint)
        }
        .perchCard()
    }
}

private struct HoldingEditorView: View {
    let holding: Holding?
    let stocks: [Stock]
    let onSave: (String, Double, Decimal, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ticker: String
    @State private var shares: String
    @State private var averageCost: String
    @State private var isSaving = false

    init(
        holding: Holding?,
        stocks: [Stock],
        onSave: @escaping (String, Double, Decimal, String?) async -> Void
    ) {
        self.holding = holding
        self.stocks = stocks
        self.onSave = onSave
        _ticker = State(initialValue: holding?.ticker ?? "")
        _shares = State(initialValue: holding.map { String(format: "%.2f", $0.shares) } ?? "")
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
        return parsedShares > 0 && parsedAverageCost >= 0
    }

    private var selectedStock: Stock? {
        let symbol = TickerMapper.symbol(from: ticker)
        return stocks.first { $0.ticker == symbol } ?? (TickerMapper.isValid(symbol) ? MockData.generatedStock(ticker: symbol) : nil)
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
                        LabeledContent("Last price", value: CurrencyFormatter.dollars(stock.price))
                        LabeledContent("Market value", value: CurrencyFormatter.dollars(stock.price * Decimal(parsedShares)))
                        LabeledContent("Cost basis", value: CurrencyFormatter.dollars(parsedAverageCost * Decimal(parsedShares)))
                    }
                }

                if TickerMapper.isValid(ticker), stocks.contains(where: { $0.ticker == TickerMapper.symbol(from: ticker) }) == false {
                    Section {
                        Text("This symbol is not in the bundled sample data. Perch will add it with a placeholder quote, ready for live market data integration.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
                            await onSave(TickerMapper.symbol(from: ticker), parsedShares, parsedAverageCost, holding?.ticker)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }
}
