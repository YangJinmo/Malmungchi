import Foundation
import Testing
@testable import Malmungchi

@MainActor
@Suite("DailyDigestViewModel")
struct DailyDigestViewModelTests {
    private let day = Fixtures.date(2026, 11, 4)

    private struct SUT {
        let viewModel: DailyDigestViewModel
        let digests: InMemoryDigestRepository
        let generator: FakeDigestGenerator
    }

    private func makeSUT(generator: FakeDigestGenerator = FakeDigestGenerator(), withTranscript: Bool = true) throws -> SUT {
        let recording = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 9), status: .completed)
        let recordings = InMemoryRecordingRepository([recording])
        let transcripts = InMemoryTranscriptRepository()
        if withTranscript {
            try transcripts.save(
                Transcript(recordingID: recording.id, language: "ko", segments: [TranscriptSegment(start: 0, end: 2, text: "안녕")], createdAt: recording.createdAt),
                for: recording
            )
        }
        let digests = InMemoryDigestRepository()
        let viewModel = DailyDigestViewModel(
            date: day,
            fetchDigest: FetchDailyDigestUseCase(digests: digests, calendar: Fixtures.seoulCalendar),
            generateDigest: GenerateDailyDigestUseCase(
                recordings: recordings, transcripts: transcripts, digests: digests,
                generator: generator, calendar: Fixtures.seoulCalendar,
                now: { Fixtures.date(2026, 11, 4, 23) }
            )
        )
        return SUT(viewModel: viewModel, digests: digests, generator: generator)
    }

    @Test("저장된 정리가 있으면 load로 보여준다")
    func loadShowsExistingDigest() throws {
        let sut = try makeSUT()
        let digest = DailyDigest(date: day, diary: "저장된 일기", todos: [], decisions: [], generatedAt: day, model: "m")
        try sut.digests.save(digest)

        sut.viewModel.load()

        #expect(sut.viewModel.digest == digest)
    }

    @Test("정리를 만들면 결과를 보여주고 진행 표시를 끈다")
    func generateShowsResult() async throws {
        let sut = try makeSUT()

        await sut.viewModel.generate()

        #expect(sut.viewModel.digest?.diary == Fixtures.sampleContent.diary)
        #expect(!sut.viewModel.isGenerating)
        #expect(sut.viewModel.errorMessage == nil)
    }

    @Test("실패하면 이유를 보여주고 이전 정리는 남긴다")
    func failureKeepsPreviousDigest() async throws {
        let sut = try makeSUT()
        await sut.viewModel.generate()
        let previous = sut.viewModel.digest

        sut.generator.result = .failure(DigestGenerationError.missingAPIKey)
        await sut.viewModel.generate()

        #expect(sut.viewModel.digest == previous)
        #expect(sut.viewModel.errorMessage == DigestGenerationError.missingAPIKey.errorDescription)
        #expect(!sut.viewModel.isGenerating)
    }

    @Test("받아쓰기가 없는 날은 안내 문구를 보여준다")
    func nothingToDigestMessage() async throws {
        let sut = try makeSUT(withTranscript: false)

        await sut.viewModel.generate()

        #expect(sut.viewModel.digest == nil)
        #expect(sut.viewModel.errorMessage == DigestGenerationError.nothingToDigest.errorDescription)
        #expect(sut.generator.inputs.isEmpty)
    }
}
