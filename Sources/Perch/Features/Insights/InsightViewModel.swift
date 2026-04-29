import Foundation

@MainActor
final class InsightViewModel: ObservableObject {
    @Published private(set) var insights: [StockInsight] = []
    @Published var isGenerating = false
    @Published var errorMessage: String?

    private let repository: MarketRepositoryProtocol

    init(repository: MarketRepositoryProtocol) {
        self.repository = repository
    }

    func load() async {
        do {
            insights = try await repository.loadInsights()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func regenerate() async {
        isGenerating = true
        defer { isGenerating = false }
        do {
            let insight = try await repository.regenerateInsight()
            insights.insert(insight, at: 0)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
