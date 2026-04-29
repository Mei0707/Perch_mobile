import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var state: MarketDashboardState = .empty
    @Published var errorMessage: String?

    private let repository: MarketRepositoryProtocol

    init(repository: MarketRepositoryProtocol) {
        self.repository = repository
    }

    func loadDashboard() async {
        state.isLoading = true
        do {
            state = try await repository.loadDashboard()
            errorMessage = nil
        } catch {
            state.isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}
