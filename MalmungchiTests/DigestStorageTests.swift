import Foundation
import Testing
@testable import Malmungchi

@Suite("Digest markdown & storage")
struct DigestStorageTests {
    private let recordingID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private func makeDigest(
        diary: String = "오늘은 통화가 많았다.",
        todos: [DigestTodo]? = nil,
        decisions: [DigestDecision]? = nil
    ) -> DailyDigest {
        DailyDigest(
            date: Fixtures.date(2026, 11, 4),
            diary: diary,
            todos: todos ?? [
                DigestTodo(text: "견적서 보내기", due: "금요일", source: DigestSource(recordingID: recordingID, time: 75)),
                DigestTodo(text: "우유 사기"),
            ],
            decisions: decisions ?? [
                DigestDecision(text: "디자인은 외주로 한다", source: DigestSource(recordingID: recordingID, time: nil)),
            ],
            generatedAt: Fixtures.date(2026, 11, 4, 22, 5),
            model: "test-model"
        )
    }

    private var formatter: MarkdownDigestFormatter { MarkdownDigestFormatter(timeZone: Fixtures.seoul) }

    @Test("front matter, 일기, 할 일, 결정 사항을 옵시디언 형식으로 쓴다")
    func formatsMarkdown() {
        let markdown = formatter.format(makeDigest())

        #expect(markdown.hasPrefix("---\ndate: 2026-11-04\n"))
        #expect(markdown.contains("generated: 2026-11-04T22:05:00+09:00"))
        #expect(markdown.contains("model: test-model"))
        #expect(markdown.contains("# 2026-11-04 하루 정리"))
        #expect(markdown.contains("## 일기\n\n오늘은 통화가 많았다."))
        #expect(markdown.contains("- [ ] 견적서 보내기 (금요일) [[11111111-2222-3333-4444-555555555555|01:15]]"))
        #expect(markdown.contains("- [ ] 우유 사기\n"))
        #expect(markdown.contains("- 디자인은 외주로 한다 [[11111111-2222-3333-4444-555555555555|녹음]]"))
    }

    @Test("할 일과 결정 사항이 없으면 없다고 적는다")
    func emptySections() {
        let markdown = formatter.format(makeDigest(todos: [], decisions: []))
        #expect(markdown.contains("## 할 일\n\n_없어요_"))
        #expect(markdown.contains("## 결정 사항\n\n_없어요_"))
    }

    @Test("여러 줄 항목은 한 줄로 합쳐 목록이 깨지지 않게 한다")
    func multilineItemsAreFlattened() {
        let markdown = formatter.format(makeDigest(todos: [DigestTodo(text: "첫째\n둘째")], decisions: []))
        #expect(markdown.contains("- [ ] 첫째 둘째\n"))
    }

    @Test("저장하면 json과 md가 날짜 이름으로 생기고 다시 읽을 수 있다")
    func repositoryRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("digests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try FileDigestRepository(directory: directory, formatter: formatter)
        let digest = makeDigest()

        try repository.save(digest)

        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("2026-11-04.json").path))
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("2026-11-04.md").path))
        #expect(try repository.digest(on: digest.date) == digest)
    }

    @Test("정리가 없는 날은 nil이다")
    func missingDigestIsNil() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("digests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try FileDigestRepository(directory: directory, formatter: formatter)
        #expect(try repository.digest(on: Fixtures.date(2026, 11, 5)) == nil)
    }

    @Test("같은 날 다시 저장하면 덮어쓴다")
    func saveOverwrites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("digests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try FileDigestRepository(directory: directory, formatter: formatter)

        try repository.save(makeDigest(diary: "처음"))
        try repository.save(makeDigest(diary: "다시"))

        #expect(try repository.digest(on: Fixtures.date(2026, 11, 4))?.diary == "다시")
    }

    @Test("미리알림 기록이 없는 예전 json도 읽는다")
    func decodesDigestWithoutRemindedIDs() throws {
        let json = """
        {"date":"2026-11-03T15:00:00Z","diary":"a","todos":[],"decisions":[],"generatedAt":"2026-11-04T13:00:00Z","model":"m"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let digest = try decoder.decode(DailyDigest.self, from: Data(json.utf8))

        #expect(digest.remindedTodoIDs.isEmpty)
    }
}
