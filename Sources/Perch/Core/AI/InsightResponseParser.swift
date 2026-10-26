import Foundation

struct InsightResponseParser {
    func parse(_ data: Data) throws -> AssistantAnswer {
        let answer = try APIClient.decoder().decode(AssistantAnswer.self, from: data)
        try validate(answer)
        return answer
    }

    func validate(_ answer: AssistantAnswer) throws {
        let known = Set(answer.facts.map(\.id))
        guard !answer.title.isEmpty, !answer.explanation.isEmpty,
              answer.factIDs.allSatisfy({ known.contains($0) }),
              known.count == answer.facts.count,
              UUID(uuidString: answer.id) != nil,
              ["complete", "incomplete"].contains(answer.coverage),
              ["fresh", "stale", "unavailable"].contains(answer.freshness),
              ["llm", "fallback"].contains(answer.mode) else { throw NetworkError.decodingFailed }
    }
}
