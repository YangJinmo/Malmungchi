import Foundation
import Testing
@testable import Malmungchi

@Suite("ImportSharedAudioUseCase")
struct ImportSharedAudioUseCaseTests {
    private let first = URL(fileURLWithPath: "/inbox/a/통화 1.m4a")
    private let second = URL(fileURLWithPath: "/inbox/b/통화 2.m4a")

    private func makeSUT(inbox: InMemorySharedAudioInbox) -> (ImportSharedAudioUseCase, InMemoryRecordingRepository, FakeAudioStorage) {
        let recordings = InMemoryRecordingRepository()
        let storage = FakeAudioStorage()
        let useCase = ImportSharedAudioUseCase(
            inbox: inbox,
            importAudio: ImportAudioUseCase(storage: storage, repository: recordings)
        )
        return (useCase, recordings, storage)
    }

    @Test("대기 중인 파일을 모두 가져오고 Inbox에서 지운다")
    func importsAndRemoves() async throws {
        let inbox = InMemorySharedAudioInbox(files: [first, second])
        let (useCase, recordings, storage) = makeSUT(inbox: inbox)

        let result = try await useCase.execute()

        #expect(result.imported.count == 2)
        #expect(result.failedCount == 0)
        #expect(result.imported.allSatisfy { $0.source == .imported })
        #expect(Set(result.imported.map(\.title)) == ["통화 1", "통화 2"])
        #expect(storage.importedSources == [first, second])
        #expect(try recordings.fetchAll().count == 2)
        #expect(inbox.files.isEmpty)
    }

    @Test("하나가 실패해도 나머지는 가져오고, 실패한 파일은 남긴다")
    func failureKeepsFileAndContinues() async throws {
        let inbox = InMemorySharedAudioInbox(files: [first, second])
        let (useCase, _, storage) = makeSUT(inbox: inbox)
        storage.failingSources = [first]

        let result = try await useCase.execute()

        #expect(result.imported.map(\.title) == ["통화 2"])
        #expect(result.failedCount == 1)
        #expect(inbox.files == [first])
    }

    @Test("Inbox가 비어 있으면 아무 일도 하지 않는다")
    func emptyInbox() async throws {
        let (useCase, recordings, storage) = makeSUT(inbox: InMemorySharedAudioInbox())

        let result = try await useCase.execute()

        #expect(result == SharedImportResult(imported: [], failedCount: 0))
        #expect(storage.importedSources.isEmpty)
        #expect(try recordings.fetchAll().isEmpty)
    }

    @Test("Inbox를 읽지 못하면 에러를 던진다")
    func listFailurePropagates() async {
        let inbox = InMemorySharedAudioInbox()
        inbox.listError = StubError()
        let (useCase, _, _) = makeSUT(inbox: inbox)

        await #expect(throws: StubError.self) {
            try await useCase.execute()
        }
    }
}

@Suite("SharedInbox files")
struct SharedInboxFileTests {
    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeSource(named name: String = "source.m4a", contents: String = "audio") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(name)")
        try Data(contents.utf8).write(to: url)
        return url
    }

    @Test("stage는 uuid 폴더 아래 원래 이름으로 복사한다")
    func stageCopiesUnderUUIDFolder() throws {
        let root = makeRoot()
        let source = try makeSource()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: source) }

        let staged = try SharedInbox.stage(fileAt: source, originalName: "통화 녹음.m4a", in: root)

        #expect(staged.lastPathComponent == "통화 녹음.m4a")
        #expect(staged.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL)
        #expect(UUID(uuidString: staged.deletingLastPathComponent().lastPathComponent) != nil)
        #expect(try String(contentsOf: staged, encoding: .utf8) == "audio")
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test("이름의 경로 문자는 걸러내고, 비면 기본 이름을 쓴다")
    func safeFileNames() {
        let source = URL(fileURLWithPath: "/tmp/x.m4a")
        #expect(SharedInbox.safeFileName("../../etc/passwd", source: source) == "passwd")
        #expect(SharedInbox.safeFileName("a\\b\\c.m4a", source: source) == "c.m4a")
        #expect(SharedInbox.safeFileName("  ", source: URL(fileURLWithPath: "/")) == SharedInbox.fallbackFileName)
        #expect(SharedInbox.safeFileName("..", source: source) == SharedInbox.fallbackFileName)
        #expect(SharedInbox.safeFileName(nil, source: source) == "x.m4a")
    }

    @Test("복사에 실패하면 만든 폴더를 남기지 않는다")
    func stageFailureCleansUp() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(throws: (any Error).self) {
            try SharedInbox.stage(fileAt: URL(fileURLWithPath: "/no/such/file.m4a"), originalName: nil, in: root)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test("Inbox가 없으면 빈 목록이다")
    func missingRootIsEmpty() throws {
        #expect(try FileSharedAudioInbox(root: makeRoot()).pendingFiles().isEmpty)
    }

    @Test("대기 파일을 오래된 순으로 읽고, 숨김 파일과 일반 파일은 무시한다")
    func listsOldestFirst() throws {
        let root = makeRoot()
        let source = try makeSource()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: source) }

        let newer = try SharedInbox.stage(fileAt: source, originalName: "newer.m4a", in: root)
        let older = try SharedInbox.stage(fileAt: source, originalName: "older.m4a", in: root)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000)], ofItemAtPath: older.deletingLastPathComponent().path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2_000)], ofItemAtPath: newer.deletingLastPathComponent().path)
        try Data().write(to: root.appendingPathComponent(".DS_Store"))
        try Data().write(to: root.appendingPathComponent("stray.txt"))

        let files = try FileSharedAudioInbox(root: root).pendingFiles()

        #expect(files.map(\.lastPathComponent) == ["older.m4a", "newer.m4a"])
    }

    @Test("remove는 공유 폴더째 지운다")
    func removeDeletesFolder() throws {
        let root = makeRoot()
        let source = try makeSource()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: source) }
        let staged = try SharedInbox.stage(fileAt: source, originalName: "a.m4a", in: root)
        let inbox = FileSharedAudioInbox(root: root)

        try inbox.remove(staged)

        #expect(!FileManager.default.fileExists(atPath: staged.deletingLastPathComponent().path))
        #expect(try inbox.pendingFiles().isEmpty)
    }
}
