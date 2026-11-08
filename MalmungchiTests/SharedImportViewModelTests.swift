import Foundation
import Testing
@testable import Malmungchi

@MainActor
@Suite("RecordingListViewModel shared import")
struct SharedImportViewModelTests {
    private struct SUT {
        let viewModel: RecordingListViewModel
        let inbox: InMemorySharedAudioInbox
        let storage: FakeAudioStorage
        let recordings: InMemoryRecordingRepository
        let transcripts: InMemoryTranscriptRepository
    }

    private let file = URL(fileURLWithPath: "/inbox/a/통화.m4a")
    private let other = URL(fileURLWithPath: "/inbox/b/메모.m4a")

    private func makeSUT(files: [URL], withSharedImport: Bool = true) -> SUT {
        let recordings = InMemoryRecordingRepository()
        let transcripts = InMemoryTranscriptRepository()
        let storage = FakeAudioStorage()
        let inbox = InMemorySharedAudioInbox(files: files)
        let importAudio = ImportAudioUseCase(storage: storage, repository: recordings)
        let viewModel = RecordingListViewModel(
            fetchRecordings: FetchRecordingsUseCase(repository: recordings),
            recordAudio: RecordAudioUseCase(recorder: FakeAudioRecorder(), storage: storage, repository: recordings),
            importAudio: importAudio,
            transcribeRecording: TranscribeRecordingUseCase(
                recordings: recordings, transcripts: transcripts, storage: storage,
                transcriber: FakeTranscriber(result: .success(Fixtures.sampleOutput))
            ),
            deleteRecording: DeleteRecordingUseCase(recordings: recordings, transcripts: transcripts, storage: storage),
            importSharedAudio: withSharedImport ? ImportSharedAudioUseCase(inbox: inbox, importAudio: importAudio) : nil,
            calendar: Fixtures.seoulCalendar
        )
        return SUT(viewModel: viewModel, inbox: inbox, storage: storage, recordings: recordings, transcripts: transcripts)
    }

    @Test("공유로 받은 파일을 가져와 목록에 보이고 받아쓰기까지 한다")
    func importsAndTranscribes() async throws {
        let sut = makeSUT(files: [file])

        await sut.viewModel.importSharedItems()

        let recording = try #require(sut.viewModel.days.first?.recordings.first)
        #expect(recording.title == "통화")
        #expect(recording.status == .completed)
        #expect(sut.transcripts.items[recording.id] != nil)
        #expect(sut.viewModel.noticeMessage == "1개를 가져왔어요.")
        #expect(sut.inbox.files.isEmpty)
    }

    @Test("자동 받아쓰기를 끄면 가져오기만 한다")
    func autoTranscribeOff() async throws {
        let sut = makeSUT(files: [file])
        sut.viewModel.autoTranscribe = false

        await sut.viewModel.importSharedItems()

        #expect(sut.viewModel.days.first?.recordings.first?.status == .pending)
        #expect(sut.transcripts.items.isEmpty)
    }

    @Test("가져올 파일이 없으면 안내도 변화도 없다")
    func nothingPending() async {
        let sut = makeSUT(files: [])

        await sut.viewModel.importSharedItems()

        #expect(sut.viewModel.noticeMessage == nil)
        #expect(sut.viewModel.errorMessage == nil)
        #expect(sut.viewModel.days.isEmpty)
    }

    @Test("일부만 실패하면 개수를 나눠 알리고 실패한 파일은 남긴다")
    func partialFailureNotice() async {
        let sut = makeSUT(files: [file, other])
        sut.storage.failingSources = [other]

        await sut.viewModel.importSharedItems()

        #expect(sut.viewModel.noticeMessage == "1개를 가져왔어요. 1개는 가져오지 못해서 다음에 다시 시도해요.")
        #expect(sut.inbox.files == [other])
    }

    @Test("앱 그룹을 쓸 수 없는 환경(가져오기 없음)에서는 아무 일도 하지 않는다")
    func noSharedImportConfigured() async {
        let sut = makeSUT(files: [file], withSharedImport: false)

        await sut.viewModel.importSharedItems()

        #expect(sut.viewModel.days.isEmpty)
        #expect(sut.viewModel.noticeMessage == nil)
        #expect(sut.inbox.files == [file])
    }

    @Test("Inbox를 읽지 못하면 에러를 보여준다")
    func listFailureShowsError() async {
        let sut = makeSUT(files: [file])
        sut.inbox.listError = StubError()

        await sut.viewModel.importSharedItems()

        #expect(sut.viewModel.errorMessage == "stub failure")
    }
}
