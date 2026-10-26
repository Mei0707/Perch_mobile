import Foundation

@MainActor
enum VerifyChat {
    static func run(directory: URL) async throws {
        let store = HoldingsStore(directory: directory.appendingPathComponent("chat-store"))
        try store.save([Holding(ticker: "AAPL", shares: 10, averageCost: 8)])
        let repository = MarketRepository(cache: CacheManager(directory: directory.appendingPathComponent("chat-cache")), store: store, useBackend: { false })
        let client = ChatFixtureClient()
        let disconnected = InsightViewModel(repository: repository, api: client,
                                             historyURL: directory.appendingPathComponent("disconnected.json"), isConfigured: { false })
        disconnected.send("Explain my portfolio")
        try check(disconnected.turns.isEmpty && client.requestCount == 0 && disconnected.errorMessage != nil, "Disconnected onboarding")

        let success = InsightViewModel(repository: repository, api: client,
                                        historyURL: directory.appendingPathComponent("success.json"), isConfigured: { true })
        success.send("Explain my portfolio")
        try await wait { !success.isGenerating }
        try check(success.turns.count == 2 && success.turns.last?.answer != nil && !success.canRetry, "Completed answer cannot be retried by mistake")

        client.mode = .failure
        let failureURL = directory.appendingPathComponent("failure.json")
        let failed = InsightViewModel(repository: repository, api: client, historyURL: failureURL, isConfigured: { true })
        failed.send("Retry this question")
        try await wait { !failed.isGenerating }
        try check(failed.turns.count == 1 && failed.canRetry && !String(contentsOf: failureURL).contains("unverified-draft"), "Failed drafts are removed from UI and disk")
        client.mode = .success
        failed.retry()
        try await wait { !failed.isGenerating }
        try check(failed.turns.filter { $0.role == "user" }.count == 1 && failed.turns.last?.answer != nil, "Retry preserves one copy of the question")

        client.mode = .waiting
        let stopped = InsightViewModel(repository: repository, api: client, historyURL: directory.appendingPathComponent("stopped.json"), isConfigured: { true })
        stopped.send("Stop this response")
        try await wait { stopped.turns.last?.content == "unverified-draft" }
        stopped.stop()
        try await wait { !stopped.isGenerating }
        try check(stopped.turns.count == 1 && stopped.canRetry && stopped.errorMessage?.contains("stopped") == true, "Cancellation clears draft and allows retry")

        guard let turn = success.turns.last else { throw VerificationFailure.failed("Missing feedback fixture") }
        async let first: Void = success.rate(turn, rating: "helpful")
        async let second: Void = success.rate(turn, rating: "helpful")
        _ = await (first, second)
        await success.rate(turn, rating: "helpful")
        try check(client.feedbackCount == 1 && success.turns.last?.rating == "helpful", "Feedback duplicate suppression")

        try await repository.saveHolding(Holding(ticker: "MSFT", shares: 5, averageCost: 9), replacing: nil)
        var rejected = false
        do { try await repository.saveHolding(Holding(ticker: "MSFT", shares: 99, averageCost: 1), replacing: "AAPL") }
        catch HoldingsError.duplicateTicker { rejected = true }
        let holdings = try await repository.loadHoldings()
        try check(rejected && holdings.count == 2 && holdings.first(where: { $0.ticker == "MSFT" })?.shares == 5, "Ticker rename preserves the other holding")
        print("7 chat and portfolio behavior checks passed")
    }

    private static func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        throw VerificationFailure.failed("Timed out waiting for chat state")
    }
    private static func check(_ condition: @autoclosure () throws -> Bool, _ label: String) throws {
        if try !condition() { throw VerificationFailure.failed(label) }
    }
    private enum VerificationFailure: Error { case failed(String) }
}

@MainActor
private final class ChatFixtureClient: AssistantClient {
    enum Mode { case success, failure, waiting }
    var mode: Mode = .success
    var requestCount = 0
    var feedbackCount = 0
    func stream(_ input: AssistantRequest, onEvent: @escaping (AssistantEvent) async -> Void) async throws {
        requestCount += 1
        await onEvent(AssistantEvent(type: "draft", name: nil, message: nil, text: "unverified-draft", answer: nil))
        if mode == .failure { throw NetworkError.interrupted }
        if mode == .waiting { try await Task.sleep(nanoseconds: 60_000_000_000) }
        let answer = AssistantAnswer(id: UUID().uuidString, title: "Fixture", explanation: "Calculated fixture result", mode: "llm", facts: [],
                                     factIDs: [], limitations: [], sources: [], coverage: "complete", freshness: "fresh", asOf: .now, toolCalls: ["getPortfolio"], latencyMs: 1)
        await onEvent(AssistantEvent(type: "complete", name: nil, message: nil, text: nil, answer: answer))
    }
    func feedback(answerID: String, rating: String) async throws {
        feedbackCount += 1
        try await Task.sleep(nanoseconds: 20_000_000)
    }
}
