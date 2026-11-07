import Foundation
import Testing
@testable import Malmungchi

/// 실제 파일 시스템을 쓰는 Data 계층 테스트. 테스트마다 임시 폴더를 만든다.
@Suite("File repositories")
struct FileRepositoryTests {
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MalmungchiTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test("녹음 목록을 저장하고 새 인스턴스에서 다시 읽는다")
    func recordingRoundTrip() throws {
        let fileURL = directory.appendingPathComponent("recordings.json")
        let older = Fixtures.recording(at: Fixtures.date(2026, 11, 1))
        var newer = Fixtures.recording(at: Fixtures.date(2026, 11, 4))

        let repository = JSONRecordingRepository(fileURL: fileURL)
        try repository.save(older)
        try repository.save(newer)
        newer.status = .failed(message: "네트워크")
        try repository.save(newer)

        let reloaded = try JSONRecordingRepository(fileURL: fileURL).fetchAll()
        #expect(reloaded.map(\.id) == [newer.id, older.id])
        #expect(reloaded.first?.status == .failed(message: "네트워크"))
    }

    @Test("손상된 파일은 백업하고 corrupted 에러를 낸다")
    func corruptedFileIsBackedUp() throws {
        let fileURL = directory.appendingPathComponent("recordings.json")
        try Data("not json".utf8).write(to: fileURL)

        #expect(throws: JSONRecordingRepository.RepositoryError.self) {
            try JSONRecordingRepository(fileURL: fileURL).fetchAll()
        }

        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.contains("corrupt") }
        #expect(backups.count == 1)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("받아쓰기를 JSON과 마크다운으로 저장하고, 삭제하면 둘 다 지운다")
    func transcriptFiles() throws {
        let repository = try FileTranscriptRepository(
            directory: directory,
            formatter: MarkdownTranscriptFormatter(timeZone: Fixtures.seoul)
        )
        let recording = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 9))
        let transcript = Transcript(
            recordingID: recording.id,
            language: "ko",
            segments: [TranscriptSegment(start: 0, end: 2, text: "테스트")],
            createdAt: recording.createdAt
        )

        try repository.save(transcript, for: recording)

        #expect(try repository.transcript(for: recording.id) == transcript)
        let markdownURL = directory.appendingPathComponent("\(recording.id.uuidString).md")
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("[00:00] 테스트"))

        try repository.delete(for: recording.id)
        #expect(try repository.transcript(for: recording.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: markdownURL.path))
    }
}
