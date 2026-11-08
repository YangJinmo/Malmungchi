import Foundation

enum DigestParseError: Error, Equatable, LocalizedError {
    case invalidJSON(String)
    case emptyDiary

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let detail): return "정리 결과를 읽지 못했어요. (\(detail))"
        case .emptyDiary: return "정리 결과에 일기 내용이 없어요."
        }
    }
}

/// LLM이 돌려준 JSON을 `DigestContent`로 바꾼다.
///
/// 기대하는 모양:
/// `{"diary": "...", "todos": [{"text", "due"?, "recording"?, "at"?}], "decisions": [{"text", "recording"?, "at"?}]}`
/// `recording`은 입력의 녹음 번호, `at`은 녹음 시작 기준 초다.
struct DigestParser {
    private struct Payload: Decodable {
        struct Item: Decodable {
            let text: String
            let due: String?
            let recording: Int?
            let at: Double?
        }

        let diary: String
        let todos: [Item]?
        let decisions: [Item]?
    }

    func parse(_ data: Data, entries: [DigestInput.Entry]) throws -> DigestContent {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw DigestParseError.invalidJSON(Self.describe(error))
        }

        let diary = payload.diary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !diary.isEmpty else { throw DigestParseError.emptyDiary }

        let idsByNumber = Dictionary(entries.map { ($0.number, $0.recordingID) }, uniquingKeysWith: { first, _ in first })

        func source(for item: Payload.Item) -> DigestSource? {
            guard let number = item.recording, let id = idsByNumber[number] else { return nil }
            return DigestSource(recordingID: id, time: item.at.flatMap { $0 >= 0 ? $0 : nil })
        }

        func clean(_ text: String?) -> String? {
            guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
            return trimmed
        }

        let todos = (payload.todos ?? []).compactMap { item -> DigestTodo? in
            guard let text = clean(item.text) else { return nil }
            return DigestTodo(text: text, due: clean(item.due), source: source(for: item))
        }
        let decisions = (payload.decisions ?? []).compactMap { item -> DigestDecision? in
            guard let text = clean(item.text) else { return nil }
            return DigestDecision(text: text, source: source(for: item))
        }

        return DigestContent(diary: diary, todos: todos, decisions: decisions)
    }

    private static func describe(_ error: Error) -> String {
        guard let decoding = error as? DecodingError else { return "JSON이 아니에요" }
        switch decoding {
        case .keyNotFound(let key, _): return "\(key.stringValue) 항목이 없어요"
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "\(context.codingPath.map(\.stringValue).joined(separator: ".")) 형식이 달라요"
        case .dataCorrupted: return "JSON이 아니에요"
        @unknown default: return "알 수 없는 형식이에요"
        }
    }
}
