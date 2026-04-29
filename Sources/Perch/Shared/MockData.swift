import Foundation

enum MockData {
    static let stocks: [Stock] = [
        Stock(
            ticker: "AAPL",
            name: "Apple Inc.",
            exchange: "NASDAQ",
            sector: .technology,
            price: 189.98,
            change: 2.48,
            changePercent: 1.32,
            open: 188.10,
            high: 190.35,
            low: 187.40,
            previousClose: 187.50,
            volume: "34.21M",
            marketCap: "2.93T",
            peRatio: "28.56",
            summary: "Strong iPhone demand and services growth continue to support revenue resilience.",
            sentiment: .bullish,
            chart: makeChart(seed: 1001, points: 48, base: 174, volatility: 3.2)
        ),
        Stock(
            ticker: "MSFT",
            name: "Microsoft Corp.",
            exchange: "NASDAQ",
            sector: .technology,
            price: 415.26,
            change: 3.68,
            changePercent: 0.89,
            open: 412.50,
            high: 416.80,
            low: 411.20,
            previousClose: 411.58,
            volume: "18.43M",
            marketCap: "3.09T",
            peRatio: "36.12",
            summary: "Azure and Copilot adoption continue to drive enterprise upgrade cycles.",
            sentiment: .bullish,
            chart: makeChart(seed: 2001, points: 48, base: 392, volatility: 5.0)
        ),
        Stock(
            ticker: "NVDA",
            name: "NVIDIA Corp.",
            exchange: "NASDAQ",
            sector: .technology,
            price: 1024.31,
            change: 15.62,
            changePercent: 1.55,
            open: 1010.20,
            high: 1028.50,
            low: 1006.80,
            previousClose: 1008.69,
            volume: "42.87M",
            marketCap: "2.52T",
            peRatio: "72.40",
            summary: "Data center GPU demand remains elevated as AI infrastructure spending expands.",
            sentiment: .bullish,
            chart: makeChart(seed: 3001, points: 48, base: 930, volatility: 18.0)
        ),
        Stock(
            ticker: "AMZN",
            name: "Amazon.com Inc.",
            exchange: "NASDAQ",
            sector: .consumer,
            price: 186.02,
            change: -1.20,
            changePercent: -0.65,
            open: 187.50,
            high: 188.10,
            low: 185.30,
            previousClose: 187.22,
            volume: "28.14M",
            marketCap: "1.94T",
            peRatio: "44.82",
            summary: "AWS margin expansion remains constructive while retail growth normalizes.",
            sentiment: .neutral,
            chart: makeChart(seed: 4001, points: 48, base: 178, volatility: 3.8)
        ),
        Stock(
            ticker: "GOOGL",
            name: "Alphabet Inc.",
            exchange: "NASDAQ",
            sector: .communication,
            price: 166.51,
            change: 1.46,
            changePercent: 0.88,
            open: 165.20,
            high: 167.30,
            low: 164.80,
            previousClose: 165.05,
            volume: "22.65M",
            marketCap: "2.06T",
            peRatio: "24.68",
            summary: "Search monetization is steady, with cloud and YouTube providing upside.",
            sentiment: .bullish,
            chart: makeChart(seed: 5001, points: 48, base: 158, volatility: 2.6)
        ),
        Stock(
            ticker: "TSLA",
            name: "Tesla Inc.",
            exchange: "NASDAQ",
            sector: .consumer,
            price: 174.62,
            change: -3.84,
            changePercent: -2.15,
            open: 178.20,
            high: 179.05,
            low: 173.88,
            previousClose: 178.46,
            volume: "91.34M",
            marketCap: "556.12B",
            peRatio: "48.90",
            summary: "Vehicle margin pressure remains the key debate as energy storage growth improves.",
            sentiment: .neutral,
            chart: makeChart(seed: 6001, points: 48, base: 188, volatility: 7.5)
        ),
        Stock(
            ticker: "META",
            name: "Meta Platforms Inc.",
            exchange: "NASDAQ",
            sector: .communication,
            price: 493.14,
            change: 5.92,
            changePercent: 1.21,
            open: 487.45,
            high: 496.10,
            low: 486.80,
            previousClose: 487.22,
            volume: "14.82M",
            marketCap: "1.25T",
            peRatio: "25.34",
            summary: "Ad demand remains firm while AI recommendation systems support engagement.",
            sentiment: .bullish,
            chart: makeChart(seed: 7001, points: 48, base: 452, volatility: 8.0)
        ),
        Stock(
            ticker: "AMD",
            name: "Advanced Micro Devices",
            exchange: "NASDAQ",
            sector: .technology,
            price: 158.44,
            change: 4.38,
            changePercent: 2.84,
            open: 154.18,
            high: 159.20,
            low: 153.65,
            previousClose: 154.06,
            volume: "55.06M",
            marketCap: "256.30B",
            peRatio: "61.22",
            summary: "AI accelerator expectations continue to influence near-term multiple expansion.",
            sentiment: .bullish,
            chart: makeChart(seed: 8001, points: 48, base: 138, volatility: 6.6)
        ),
        Stock(
            ticker: "JPM",
            name: "JPMorgan Chase & Co.",
            exchange: "NYSE",
            sector: .financials,
            price: 198.17,
            change: 1.06,
            changePercent: 0.54,
            open: 197.40,
            high: 199.18,
            low: 196.82,
            previousClose: 197.11,
            volume: "8.77M",
            marketCap: "568.42B",
            peRatio: "12.01",
            summary: "Net interest income and credit quality remain the primary investor focus.",
            sentiment: .neutral,
            chart: makeChart(seed: 9001, points: 48, base: 184, volatility: 2.8)
        ),
        Stock(
            ticker: "UNH",
            name: "UnitedHealth Group",
            exchange: "NYSE",
            sector: .healthcare,
            price: 512.70,
            change: -4.15,
            changePercent: -0.80,
            open: 517.20,
            high: 518.44,
            low: 510.90,
            previousClose: 516.85,
            volume: "3.45M",
            marketCap: "471.80B",
            peRatio: "21.66",
            summary: "Managed care utilization trends are steady, but regulatory headlines remain a risk.",
            sentiment: .neutral,
            chart: makeChart(seed: 10001, points: 48, base: 525, volatility: 5.1)
        ),
        Stock(
            ticker: "NFLX",
            name: "Netflix Inc.",
            exchange: "NASDAQ",
            sector: .communication,
            price: 628.35,
            change: 9.74,
            changePercent: 1.57,
            open: 619.11,
            high: 631.04,
            low: 617.28,
            previousClose: 618.61,
            volume: "4.16M",
            marketCap: "270.05B",
            peRatio: "43.28",
            summary: "Subscriber growth and ad-tier monetization are supporting stronger margin expectations.",
            sentiment: .bullish,
            chart: makeChart(seed: 11001, points: 48, base: 590, volatility: 10.4)
        ),
        Stock(
            ticker: "COST",
            name: "Costco Wholesale Corp.",
            exchange: "NASDAQ",
            sector: .consumer,
            price: 742.88,
            change: 2.19,
            changePercent: 0.30,
            open: 741.40,
            high: 745.21,
            low: 738.02,
            previousClose: 740.69,
            volume: "1.79M",
            marketCap: "329.42B",
            peRatio: "48.15",
            summary: "Membership renewal rates and steady traffic keep defensive growth characteristics intact.",
            sentiment: .bullish,
            chart: makeChart(seed: 12001, points: 48, base: 704, volatility: 6.4)
        )
    ]

    static let holdings: [Holding] = [
        Holding(ticker: "AAPL", shares: 42, averageCost: 152.30),
        Holding(ticker: "MSFT", shares: 18, averageCost: 310.00),
        Holding(ticker: "NVDA", shares: 5, averageCost: 680.00),
        Holding(ticker: "AMZN", shares: 30, averageCost: 175.40),
        Holding(ticker: "GOOGL", shares: 35, averageCost: 140.20),
        Holding(ticker: "META", shares: 9, averageCost: 388.10),
        Holding(ticker: "AMD", shares: 24, averageCost: 119.80),
        Holding(ticker: "JPM", shares: 12, averageCost: 161.40)
    ]

    static let indices: [MarketIndex] = [
        MarketIndex(name: "S&P 500", value: "5,324", changePercent: 0.80),
        MarketIndex(name: "NASDAQ", value: "16,780", changePercent: 0.74),
        MarketIndex(name: "DOW", value: "39,859", changePercent: 0.94),
        MarketIndex(name: "VIX", value: "12.45", changePercent: -3.27)
    ]

    static let sectors: [SectorSummary] = [
        SectorSummary(sector: .technology, tickers: ["AAPL", "MSFT", "NVDA"], changePercent: 2.1),
        SectorSummary(sector: .consumer, tickers: ["AMZN", "TSLA", "COST"], changePercent: 0.4),
        SectorSummary(sector: .communication, tickers: ["GOOGL", "META", "NFLX"], changePercent: 1.2),
        SectorSummary(sector: .financials, tickers: ["JPM"], changePercent: 0.5),
        SectorSummary(sector: .healthcare, tickers: ["UNH"], changePercent: -0.8)
    ]

    private static func makeChart(seed: UInt64, points: Int, base: Double, volatility: Double) -> [Double] {
        var state = seed
        var value = base
        return (0..<points).map { _ in
            state = state &* 1_664_525 &+ 1_013_904_223
            let normalized = Double(state % 1_000) / 1_000
            value += (normalized - 0.46) * volatility
            return max(value, 1)
        }
    }

    static func generatedStock(ticker rawTicker: String) -> Stock {
        let ticker = TickerMapper.symbol(from: rawTicker)
        let seed = UInt64(ticker.unicodeScalars.reduce(0) { $0 + Int($1.value) })
        let base = 35 + Double(seed % 420)
        let changePercent = (Double(Int(seed % 700)) / 100) - 3.5
        let price = Decimal(base + Double(seed % 99) / 10)
        let change = price * Decimal(changePercent / 100)
        let chart = makeChart(seed: max(seed, 1), points: 48, base: base, volatility: max(1.8, base * 0.018))

        return Stock(
            ticker: ticker,
            name: "\(ticker) Market Quote",
            exchange: "Market",
            sector: .technology,
            price: price,
            change: change,
            changePercent: changePercent,
            open: price - change,
            high: price * 1.018,
            low: price * 0.982,
            previousClose: price - change,
            volume: "--",
            marketCap: "--",
            peRatio: "--",
            summary: "Perch added \(ticker) to your portfolio with a placeholder quote. Connect a market data provider to refresh live price, fundamentals, and company details.",
            sentiment: changePercent >= 1 ? .bullish : changePercent <= -1 ? .bearish : .neutral,
            chart: chart
        )
    }
}
