import Foundation
import Testing
@testable import Malmungchi

@Suite("DigestParser")
struct DigestParserTests {
    private let first = DigestInput.Entry(number: 1, recordingID: UUID(), startedAt: Fixtures.date(2026, 11, 4, 9), segments: [])
    private let second = DigestInput.Entry(number: 2, recordingID: UUID(), startedAt: Fixtures.date(2026, 11, 4, 15), segments: [])
    private var entries: [DigestInput.Entry] { [first, second] }

    private func parse(_ json: String) throws -> DigestContent {
        try DigestParser().parse(Data(json.utf8), entries: entries)
    }

    @Test("일기, 할 일, 결정 사항을 읽고 출처를 녹음 id로 바꾼다")
    func parsesFullPayload() throws {
        let content = try parse("""
        {
          "diary": "오늘은 통화가 많았다.",
          "todos": [{"text": "견적서 보내기", "due": "금요일", "recording": 2, "at": 75.5}],
          "decisions": [{"text": "디자인은 외주로 하기로 했다", "recording": 1, "at": 12}]
        }
        """)

        #expect(content.diary == "오늘은 통화가 많았다.")
        #expect(content.todos.count == 1)
        #expect(content.todos[0].text == "견적서 보내기")
        #expect(content.todos[0].due == "금요일")
        #expect(content.todos[0].source == DigestSource(recordingID: second.recordingID, time: 75.5))
        #expect(content.decisions[0].source == DigestSource(recordingID: first.recordingID, time: 12))
    }

    @Test("할 일과 결정 사항이 없어도 일기만 있으면 된다")
    func arraysAreOptional() throws {
        let content = try parse(#"{"diary": "조용한 하루"}"#)
        #expect(content.todos.isEmpty)
        #expect(content.decisions.isEmpty)
    }

    @Test("없는 녹음 번호는 출처만 비우고 항목은 남긴다")
    func unknownRecordingNumberDropsSourceOnly() throws {
        let content = try parse(#"{"diary": "a", "todos": [{"text": "전화하기", "recording": 9, "at": 3}]}"#)
        #expect(content.todos.map(\.text) == ["전화하기"])
        #expect(content.todos[0].source == nil)
    }

    @Test("음수 시각은 버리고 녹음만 가리킨다")
    func negativeTimeIsDropped() throws {
        let content = try parse(#"{"diary": "a", "decisions": [{"text": "결정", "recording": 1, "at": -4}]}"#)
        #expect(content.decisions[0].source == DigestSource(recordingID: first.recordingID, time: nil))
    }

    @Test("공백뿐인 항목은 버리고 문장은 다듬는다")
    func trimsAndDropsBlankItems() throws {
        let content = try parse(#"{"diary": "  일기  ", "todos": [{"text": "  "}, {"text": " 사기 ", "due": " "}]}"#)
        #expect(content.diary == "일기")
        #expect(content.todos.map(\.text) == ["사기"])
        #expect(content.todos[0].due == nil)
    }

    @Test("일기가 비어 있으면 실패한다")
    func emptyDiaryFails() {
        #expect(throws: DigestParseError.emptyDiary) {
            try parse(#"{"diary": "   ", "todos": []}"#)
        }
    }

    @Test("diary 키가 없으면 어떤 항목이 없는지 알려준다")
    func missingDiaryNamesTheKey() {
        do {
            _ = try parse(#"{"todos": []}"#)
            Issue.record("실패해야 해요")
        } catch let error as DigestParseError {
            #expect(error == .invalidJSON("diary 항목이 없어요"))
        } catch {
            Issue.record("다른 에러: \(error)")
        }
    }

    @Test("JSON이 아니면 실패한다")
    func notJSONFails() {
        #expect(throws: DigestParseError.invalidJSON("JSON이 아니에요")) {
            try parse("죄송하지만 정리할 수 없어요")
        }
    }

    @Test("형식이 틀린 항목은 어느 경로인지 알려준다")
    func typeMismatchNamesThePath() {
        do {
            _ = try parse(#"{"diary": "a", "todos": [{"text": 5}]}"#)
            Issue.record("실패해야 해요")
        } catch let error as DigestParseError {
            if case .invalidJSON(let detail) = error {
                #expect(detail.contains("todos"))
            } else {
                Issue.record("다른 에러: \(error)")
            }
        } catch {
            Issue.record("다른 에러: \(error)")
        }
    }
}
