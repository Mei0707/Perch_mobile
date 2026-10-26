import Foundation

// The backend owns system instructions. User text never becomes a system prompt.
enum PromptBuilder {
    static func request(holdings: [Holding], stocks: [Stock], turns: [ConversationTurn]) -> AssistantRequest {
        let messages = turns.filter { $0.isComplete && !$0.content.isEmpty }.suffix(12).map {
            AssistantRequest.Message(role: $0.role, content: String($0.content.prefix(1600)))
        }
        return AssistantRequest(holdings: holdings, watchlist: Array(stocks.map(\.ticker).prefix(50)), messages: messages)
    }
}
