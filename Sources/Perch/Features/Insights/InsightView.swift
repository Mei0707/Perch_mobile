import SwiftUI

struct InsightView: View {
    @StateObject private var viewModel: InsightViewModel

    init(repository: MarketRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: InsightViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    if viewModel.insights.isEmpty {
                        EmptyStateView(
                            title: "No insights yet",
                            message: "Generate a market read from your watchlist and portfolio.",
                            icon: "sparkles"
                        )
                    } else {
                        ForEach(viewModel.insights) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                }
                .padding(20)
            }
            .background(.perchBackground)
            .navigationTitle("AI Insights")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await viewModel.regenerate()
                        }
                    } label: {
                        if viewModel.isGenerating {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .accessibilityLabel("Regenerate insight")
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(PerchPalette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Perch Intelligence")
                    .font(.headline)
                    .foregroundStyle(.perchText)
                Text("Market explanations, sentiment checks, and portfolio-aware alerts generated from cached stock data.")
                    .font(.subheadline)
                    .foregroundStyle(.perchMuted)
            }
        }
        .perchCard()
    }
}

private struct InsightCard: View {
    let insight: StockInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if let ticker = insight.ticker {
                            Text(ticker)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(insight.sentiment.tint, in: Capsule())
                        }
                        Text(insight.sentiment.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(insight.sentiment.tint)
                    }
                    Text(insight.title)
                        .font(.headline)
                        .foregroundStyle(.perchText)
                    Text(DateFormatter.perchShortDate.string(from: insight.generatedAt))
                        .font(.caption)
                        .foregroundStyle(.perchMuted)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(insight.confidence) / 100)
                        .stroke(insight.sentiment.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(insight.confidence)%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.perchText)
                }
                .frame(width: 46, height: 46)
            }

            Text(insight.summary)
                .font(.subheadline)
                .foregroundStyle(.perchMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .perchCard()
        .accessibilityElement(children: .combine)
    }
}
