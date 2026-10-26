import Foundation

@MainActor
final class InsightViewModel: ObservableObject {
    @Published private(set) var turns: [ConversationTurn] = []
    @Published var input = ""
    @Published private(set) var isGenerating = false
    @Published private(set) var status = ""
    @Published var errorMessage: String?
    private let repository: MarketRepositoryProtocol
    private let api: APIClient
    private var task: Task<Void, Never>?
    private let historyURL: URL

    init(repository: MarketRepositoryProtocol, api: APIClient = APIClient(), historyURL: URL? = nil) {
        self.repository = repository
        self.api = api
        self.historyURL = historyURL ?? HoldingsStore().directory.appendingPathComponent("conversation-v1.json")
        if FileManager.default.fileExists(atPath: self.historyURL.path) {
            do { turns = try APIClient.decoder().decode([ConversationTurn].self, from: Data(contentsOf: self.historyURL)) }
            catch { errorMessage = "Saved conversation could not be read. Your holdings are unaffected." }
        }
    }

    func send(_ suggestion: String? = nil) {
        let text = (suggestion ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isGenerating, !text.isEmpty, text.count <= 1600 else { return }
        input = ""
        turns.append(ConversationTurn(role: "user", content: text))
        start()
    }

    func retry() {
        guard !isGenerating else { return }
        if turns.last?.role == "assistant" && turns.last?.isComplete == false { turns.removeLast() }
        guard turns.last?.role == "user" else { return }
        start()
    }

    private func start() {
        isGenerating = true
        errorMessage = nil
        status = "Loading portfolio"
        let assistantID = UUID()
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.isGenerating = false; self.status = "" }
            do {
                let holdings = try await self.repository.loadHoldings()
                let stocks = try await self.repository.loadStocks()
                let request = PromptBuilder.request(holdings: holdings, stocks: stocks, turns: self.turns)
                self.turns.append(ConversationTurn(id: assistantID, role: "assistant", content: "", isComplete: false))
                try await self.api.stream(request) { [weak self] event in
                    self?.receive(event, id: assistantID)
                }
                try self.persist()
            } catch is CancellationError {
                self.errorMessage = "Response stopped. You can retry."
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func receive(_ event: AssistantEvent, id: UUID) {
        guard let index = turns.firstIndex(where: { $0.id == id }) else { return }
        switch event.type {
        case "tool": status = "Using \(event.name ?? "portfolio data")"
        case "status": status = event.message ?? "Checking sources"
        case "draft":
            turns[index].content = event.text ?? ""
            status = "Generating · draft is unverified"
        case "complete":
            guard let answer = event.answer else { return }
            turns[index].answer = answer
            turns[index].content = answer.explanation
            turns[index].isComplete = true
        default: break
        }
    }

    func stop() { task?.cancel() }

    func clear() {
        guard !isGenerating else { return }
        do {
            if FileManager.default.fileExists(atPath: historyURL.path) { try FileManager.default.removeItem(at: historyURL) }
            turns = []
            errorMessage = nil
        } catch { errorMessage = "Could not delete saved conversation." }
    }

    func rate(_ turn: ConversationTurn, rating: String) async {
        guard let answer = turn.answer, turn.rating == nil else { return }
        do {
            try await api.feedback(answerID: answer.id, rating: rating)
            if let index = turns.firstIndex(where: { $0.id == turn.id }) { turns[index].rating = rating }
            try persist()
        } catch { errorMessage = "Feedback was not saved. Please try again; older answers may have expired." }
    }

    private func persist() throws {
        try FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(Array(turns.filter(\.isComplete).suffix(40))).write(to: historyURL, options: .atomic)
    }
}
