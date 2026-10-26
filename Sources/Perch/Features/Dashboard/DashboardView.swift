import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @State private var showingSettings = false
    private let repository: MarketRepositoryProtocol

    init(repository: MarketRepositoryProtocol) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: DashboardViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    portfolioCard
                    Text(viewModel.state.dataStatus).font(.caption).foregroundStyle(.perchMuted)
                    if let error = viewModel.errorMessage { Text(error).font(.callout).foregroundStyle(.red) }
                    indices
                    topMovers
                    insight
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(.perchBackground)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) { PerchSettingsView(repository: repository) }
            .task {
                await viewModel.loadDashboard()
            }
            .refreshable {
                await viewModel.loadDashboard()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your market overview")
                    .font(.subheadline)
                    .foregroundStyle(.perchMuted)
                Text("Perch")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.perchText)
            }
            Spacer()
            BirdLogo()
                .frame(width: 44, height: 44)
                .background(PerchPalette.accent.opacity(0.14), in: Circle())
                .accessibilityLabel("Perch")
        }
        .padding(.top, 12)
    }

    private var portfolioCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Portfolio Value")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Label("Snapshot", systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.state.hasCompleteQuotes ? CurrencyFormatter.dollars(viewModel.state.portfolioValue) : "Unavailable")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                if viewModel.state.hasCompleteQuotes { Text("\(viewModel.state.dayGainLoss >= 0 ? "+" : "")\(CurrencyFormatter.dollars(viewModel.state.dayGainLoss)) vs previous close · \(String(format: "%.2f", viewModel.state.dayGainLossPercent))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85)) }
            }

            Text("Based on manually entered holdings; daily change assumes unchanged share quantities.")
                .font(.caption).foregroundStyle(.white.opacity(0.85))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [PerchPalette.accent, PerchPalette.accent.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: PerchPalette.accent.opacity(0.24), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .combine)
    }

    private var indices: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(viewModel.state.indices) { index in
                MetricCard(
                    title: index.name,
                    value: index.value,
                    detail: "\(index.changePercent >= 0 ? "+" : "")\(String(format: "%.2f", index.changePercent))%",
                    icon: index.isUp ? "arrow.up.right" : "arrow.down.right",
                    tint: index.isUp ? PerchPalette.gain : PerchPalette.loss
                )
            }
        }
    }

    private var topMovers: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Top Movers", systemImage: "chart.line.uptrend.xyaxis")
            VStack(spacing: 0) {
                ForEach(viewModel.state.topMovers.prefix(4)) { stock in
                    NavigationLink {
                        StockDetailView(stock: stock)
                    } label: {
                        StockRow(stock: stock)
                    }
                    .buttonStyle(.plain)
                    if stock.id != viewModel.state.topMovers.prefix(4).last?.id {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .perchCard(padding: 12)
        }
    }

    private var insight: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Portfolio explanation", systemImage: "sparkles")
            if let stockInsight = viewModel.state.insights.first {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(stockInsight.title)
                            .font(.headline)
                            .foregroundStyle(.perchText)
                        Spacer()
                        Text(stockInsight.dataStatus)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(stockInsight.sentiment.tint)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(stockInsight.sentiment.tint.opacity(0.12), in: Capsule())
                    }
                    Text(stockInsight.summary)
                        .font(.subheadline)
                        .foregroundStyle(.perchMuted)
                    if !stockInsight.sources.isEmpty {
                        DisclosureGroup("Quote sources") {
                            ForEach(Array(stockInsight.sources.enumerated()), id: \.offset) { _, source in
                                Text("\(source.ticker) · \(source.source) · \(source.freshness) · \(source.asOf.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2).foregroundStyle(.perchMuted)
                            }
                        }.font(.caption)
                    }
                }
                .perchCard()
            }
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.perchAccent)
            Text(title)
                .font(.headline)
                .foregroundStyle(.perchText)
        }
    }
}
