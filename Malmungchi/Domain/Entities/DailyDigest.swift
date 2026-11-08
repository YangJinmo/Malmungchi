import Foundation

/// 정리된 항목이 어느 녹음의 어느 지점에서 나왔는지.
struct DigestSource: Codable, Hashable, Sendable {
    let recordingID: UUID
    /// 녹음 시작 기준 초. 모르면 nil.
    let time: TimeInterval?
}

struct DigestTodo: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let text: String
    /// "내일", "금요일 오전"처럼 말한 그대로의 기한. 없으면 nil.
    let due: String?
    let source: DigestSource?

    init(id: UUID = UUID(), text: String, due: String? = nil, source: DigestSource? = nil) {
        self.id = id
        self.text = text
        self.due = due
        self.source = source
    }
}

struct DigestDecision: Codable, Hashable, Sendable {
    let text: String
    let source: DigestSource?
}

/// LLM이 만든 정리 내용. 어느 날인지, 언제 만들었는지는 모른다.
struct DigestContent: Equatable, Sendable {
    let diary: String
    let todos: [DigestTodo]
    let decisions: [DigestDecision]
}

/// 하루 정리. 하루에 하나이고, 같은 날 다시 만들면 덮어쓴다.
struct DailyDigest: Codable, Hashable, Sendable {
    /// 그 날의 0시
    let date: Date
    let diary: String
    let todos: [DigestTodo]
    let decisions: [DigestDecision]
    let generatedAt: Date
    /// 정리에 쓴 모델 이름
    let model: String
    /// 이미 미리알림에 넣은 할 일. 같은 할 일을 두 번 넣지 않는 데 쓴다.
    var remindedTodoIDs: Set<UUID> = []
}

extension DailyDigest {
    /// `remindedTodoIDs`가 없는 예전 파일도 읽는다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        diary = try container.decode(String.self, forKey: .diary)
        todos = try container.decode([DigestTodo].self, forKey: .todos)
        decisions = try container.decode([DigestDecision].self, forKey: .decisions)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        model = try container.decode(String.self, forKey: .model)
        remindedTodoIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .remindedTodoIDs) ?? []
    }
}

/// LLM에 보내는 입력. 받아쓰기 텍스트와 시각만 담고, 파일 이름·경로·제목·기기 정보는 담지 않는다.
struct DigestInput: Equatable, Sendable {
    struct Entry: Equatable, Sendable {
        /// 이 날 안에서 1부터 매긴 번호. LLM이 출처를 가리킬 때 쓴다.
        let number: Int
        /// 이 녹음을 되찾기 위한 앱 내부 id. LLM에는 보내지 않는다.
        let recordingID: UUID
        let startedAt: Date
        let segments: [TranscriptSegment]
    }

    /// 그 날의 0시
    let date: Date
    let entries: [Entry]
}
