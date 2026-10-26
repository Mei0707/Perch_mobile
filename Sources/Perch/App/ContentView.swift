import SwiftUI

public struct PerchRootView: View {
    @StateObject private var container = AppContainer()

    public init() {}

    public var body: some View {
        ContentView(repository: container.repository)
            .environmentObject(container)
    }
}

struct ContentView: View {
    let repository: MarketRepositoryProtocol

    var body: some View {
        TabView {
            DashboardView(repository: repository)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            WatchlistView(repository: repository)
                .tabItem {
                    Label("Watch", systemImage: "star.fill")
                }

            PortfolioView(repository: repository)
                .tabItem {
                    Label("Portfolio", systemImage: "briefcase.fill")
                }

            DiscoverView(repository: repository)
                .tabItem {
                    Label("Discover", systemImage: "safari.fill")
                }

            InsightView(repository: repository)
                .tabItem {
                    Label("Ask", systemImage: "sparkles")
                }
        }
        .tint(PerchPalette.accent)
    }
}
