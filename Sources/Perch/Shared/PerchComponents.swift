import SwiftUI

struct BirdLogo: View {
    var color: Color = PerchPalette.accent
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0.50, y: 0.14))
                path.addCurve(to: CGPoint(x: 0.16, y: 0.53), control1: CGPoint(x: 0.28, y: 0.14), control2: CGPoint(x: 0.12, y: 0.32))
                path.addCurve(to: CGPoint(x: 0.50, y: 0.86), control1: CGPoint(x: 0.20, y: 0.75), control2: CGPoint(x: 0.35, y: 0.86))
                path.addCurve(to: CGPoint(x: 0.82, y: 0.55), control1: CGPoint(x: 0.68, y: 0.86), control2: CGPoint(x: 0.84, y: 0.72))
                path.addCurve(to: CGPoint(x: 0.63, y: 0.20), control1: CGPoint(x: 0.80, y: 0.39), control2: CGPoint(x: 0.74, y: 0.27))
                path.addCurve(to: CGPoint(x: 0.50, y: 0.14), control1: CGPoint(x: 0.59, y: 0.16), control2: CGPoint(x: 0.54, y: 0.14))
            }
            .scale(x: size, y: size, anchor: .topLeading)
            .fill(color)

            Circle()
                .fill(.white)
                .frame(width: size * 0.11, height: size * 0.11)
                .offset(x: size * 0.13, y: -size * 0.16)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    var tint: Color = PerchPalette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.perchMuted)
                Text(value)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(.perchText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .perchCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

struct PerchProgressBar: View {
    let value: Double
    var tint: Color = PerchPalette.accent

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.07))
                Capsule()
                    .fill(tint)
                    .frame(width: max(6, proxy.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

struct Sparkline: View {
    let values: [Double]
    var tint: Color = PerchPalette.accent

    var body: some View {
        GeometryReader { proxy in
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = max(maxValue - minValue, 1)
            let points: [CGPoint] = values.enumerated().map { item in
                let x = proxy.size.width * CGFloat(item.offset) / CGFloat(max(values.count - 1, 1))
                let y = proxy.size.height - (proxy.size.height * CGFloat((item.element - minValue) / range))
                return CGPoint(x: x, y: y)
            }

            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 92)
        .accessibilityHidden(true)
    }
}

struct StockLogo: View {
    let ticker: String
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(background)
            Text(label)
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(foreground)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var label: String {
        switch ticker {
        case "NVDA": return "nv"
        case "AMZN": return "a"
        case "GOOGL": return "G"
        default: return String(ticker.prefix(2))
        }
    }

    private var background: Color {
        switch ticker {
        case "AAPL": return Color(red: 0.102, green: 0.090, blue: 0.078)
        case "MSFT": return Color(red: 0.000, green: 0.642, blue: 0.937)
        case "NVDA": return Color(red: 0.463, green: 0.725, blue: 0.000)
        case "AMZN": return Color(red: 0.137, green: 0.184, blue: 0.243)
        case "GOOGL": return .white
        default: return PerchPalette.secondarySurface
        }
    }

    private var foreground: Color {
        switch ticker {
        case "AMZN": return Color(red: 1.000, green: 0.600, blue: 0.000)
        case "GOOGL": return Color(red: 0.259, green: 0.522, blue: 0.957)
        default: return .white
        }
    }
}

struct StockRow: View {
    let stock: Stock

    var body: some View {
        HStack(spacing: 12) {
            StockLogo(ticker: stock.ticker, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(stock.ticker)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.perchText)
                Text(stock.name)
                    .font(.caption)
                    .foregroundStyle(.perchMuted)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(CurrencyFormatter.dollars(stock.price))
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(.perchText)
                Text("\(stock.changePercent >= 0 ? "+" : "")\(String(format: "%.2f", stock.changePercent))%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(stock.isUp ? PerchPalette.gain : PerchPalette.loss)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((stock.isUp ? PerchPalette.gain : PerchPalette.loss).opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

struct StockDetailView: View {
    let stock: Stock

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    StockLogo(ticker: stock.ticker, size: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stock.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.perchText)
                        Text("\(stock.ticker) · \(stock.exchange)")
                            .font(.subheadline)
                            .foregroundStyle(.perchMuted)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(CurrencyFormatter.dollars(stock.price))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.perchText)
                    Text("\(stock.change >= 0 ? "+" : "")\(CurrencyFormatter.dollars(stock.change)) today · \(String(format: "%.2f", stock.changePercent))%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(stock.isUp ? PerchPalette.gain : PerchPalette.loss)
                    Sparkline(values: stock.chart, tint: stock.isUp ? PerchPalette.gain : PerchPalette.loss)
                }
                .perchCard()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    DetailMetric(title: "Open", value: CurrencyFormatter.dollars(stock.open))
                    DetailMetric(title: "High", value: CurrencyFormatter.dollars(stock.high))
                    DetailMetric(title: "Low", value: CurrencyFormatter.dollars(stock.low))
                    DetailMetric(title: "Prev Close", value: CurrencyFormatter.dollars(stock.previousClose))
                    DetailMetric(title: "Volume", value: stock.volume)
                    DetailMetric(title: "P/E", value: stock.peRatio)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("AI Insight · \(stock.sentiment.rawValue)", systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(stock.sentiment.tint)
                    Text(stock.summary)
                        .font(.subheadline)
                        .foregroundStyle(.perchMuted)
                }
                .perchCard()
            }
            .padding(20)
        }
        .background(.perchBackground)
        .navigationTitle(stock.ticker)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct DetailMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.perchMuted)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(.perchText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .perchCard(padding: 12)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.perchAccent)
            Text(title)
                .font(.headline)
                .foregroundStyle(.perchText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.perchMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .perchCard()
    }
}
