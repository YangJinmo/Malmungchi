import Foundation
import Testing
@testable import Malmungchi

@MainActor
@Suite("RecordingListViewModel")
struct RecordingListViewModelTests {
    private struct SUT {
        let viewModel: RecordingListViewModel
        let recordings: InMemoryRecordingRepository
        let transcripts: InMemoryTranscriptRepository
        let storage: FakeAudioStorage
        let recorder: FakeAudioRecorder
    }

    private func makeSUT(
        existing: [Recording] = [],
        transcription: Result<TranscriptionOutput, Error> = .success(Fixtures.sampleOutput)
    ) -> SUT {
        let recordings = InMemoryRecordingRepository(existing)
        let transcripts = InMemoryTranscriptRepository()
        let storage = FakeAudioStorage()
        let recorder = FakeAudioRecorder()
        let transcribe = TranscribeRecordingUseCase(
            recordings: recordings,
            transcripts: transcripts,
            storage: storage,
            transcriber: FakeTranscriber(result: transcription)
        )
        let viewModel = RecordingListViewModel(
            fetchRecordings: FetchRecordingsUseCase(repository: recordings),
            recordAudio: RecordAudioUseCase(recorder: recorder, storage: storage, repository: recordings),
            importAudio: ImportAudioUseCase(storage: storage, repository: recordings),
            transcribeRecording: transcribe,
            deleteRecording: DeleteRecordingUseCase(recordings: recordings, transcripts: transcripts, storage: storage),
            calendar: Fixtures.seoulCalendar,
            now: { Fixtures.date(2026, 11, 4, 21, 41) }
        )
        return SUT(viewModel: viewModel, recordings: recordings, transcripts: transcripts, storage: storage, recorder: recorder)
    }

    @Test("load는 날짜별로 묶어 보여준다")
    func loadGroupsByDay() {
        let sut = makeSUT(existing: [
            Fixtures.recording(at: Fixtures.date(2026, 11, 3, 10)),
            Fixtures.recording(at: Fixtures.date(2026, 11, 4, 10)),
        ])

        sut.viewModel.load()

        #expect(sut.viewModel.days.map(\.date) == [Fixtures.date(2026, 11, 4), Fixtures.date(2026, 11, 3)])
    }

    @Test("가져오기 후 자동으로 받아쓴다")
    func importThenAutoTranscribe() async throws {
        let sut = makeSUT()

        await sut.viewModel.importAudio(from: URL(fileURLWithPath: "/tmp/memo.m4a"))

        let recording = try #require(sut.viewModel.days.first?.recordings.first)
        #expect(recording.status == .completed)
        #expect(try sut.transcripts.transcript(for: recording.id) != nil)
        #expect(sut.viewModel.transcribingIDs.isEmpty)
        #expect(sut.viewModel.errorMessage == nil)
    }

    @Test("자동 받아쓰기를 끄면 pending으로 남는다")
    func importWithoutAutoTranscribe() async throws {
        let sut = makeSUT()
        sut.viewModel.autoTranscribe = false

        await sut.viewModel.importAudio(from: URL(fileURLWithPath: "/tmp/memo.m4a"))

        let recording = try #require(sut.viewModel.days.first?.recordings.first)
        #expect(recording.status == .pending)
    }

    @Test("녹음 시작·종료 후 기본 제목으로 저장된다")
    func recordAndStop() async throws {
        let sut = makeSUT()
        sut.viewModel.autoTranscribe = false

        await sut.viewModel.toggleRecording()
        #expect(sut.viewModel.isRecording)

        await sut.viewModel.toggleRecording()
        #expect(!sut.viewModel.isRecording)

        let recording = try #require(sut.viewModel.days.first?.recordings.first)
        #expect(recording.title == "오후 9:41 녹음")
        #expect(recording.source == .inApp)
    }

    @Test("녹음기 실패는 에러 메시지로 보여준다")
    func recorderFailureShowsError() async {
        let sut = makeSUT()
        sut.recorder.startError = StubError()

        await sut.viewModel.toggleRecording()

        #expect(!sut.viewModel.isRecording)
        #expect(sut.viewModel.errorMessage == "stub failure")
    }

    @Test("받아쓰기 실패는 에러 메시지와 failed 상태로 남는다")
    func transcriptionFailure() async throws {
        let sut = makeSUT(transcription: .failure(StubError()))

        await sut.viewModel.importAudio(from: URL(fileURLWithPath: "/tmp/memo.m4a"))

        let recording = try #require(sut.viewModel.days.first?.recordings.first)
        #expect(recording.status == .failed(message: "stub failure"))
        #expect(sut.viewModel.errorMessage == "stub failure")
    }

    @Test("삭제하면 목록에서 사라진다")
    func deleteRemoves() {
        let existing = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 10))
        let sut = makeSUT(existing: [existing])
        sut.viewModel.load()

        sut.viewModel.delete(existing.id)

        #expect(sut.viewModel.days.isEmpty)
    }
}
