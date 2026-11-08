import Foundation
import Testing
@testable import Malmungchi

@Suite("GenerateDailyDigestUseCase")
struct DigestUseCaseTests {
    private struct SUT {
        let useCase: GenerateDailyDigestUseCase
        let recordings: InMemoryRecordingRepository
        let transcripts: InMemoryTranscriptRepository
        let digests: InMemoryDigestRepository
        let generator: FakeDigestGenerator
    }

    private func makeSUT(
        recordings existing: [Recording],
        generator: FakeDigestGenerator = FakeDigestGenerator()
    ) -> SUT {
        let recordings = InMemoryRecordingRepository(existing)
        let transcripts = InMemoryTranscriptRepository()
        let digests = InMemoryDigestRepository()
        let useCase = GenerateDailyDigestUseCase(
            recordings: recordings,
            transcripts: transcripts,
            digests: digests,
            generator: generator,
            calendar: Fixtures.seoulCalendar,
            now: { Fixtures.date(2026, 11, 4, 23, 0) }
        )
        return SUT(useCase: useCase, recordings: recordings, transcripts: transcripts, digests: digests, generator: generator)
    }

    private func addTranscript(_ sut: SUT, for recording: Recording, text: String = "내용") throws {
        try sut.transcripts.save(
            Transcript(
                recordingID: recording.id,
                language: "ko",
                segments: [TranscriptSegment(start: 0, end: 3, text: text)],
                createdAt: recording.createdAt
            ),
            for: recording
        )
    }

    @Test("그 날 받아쓰기가 끝난 녹음만 시간순으로 번호를 매겨 넘긴다")
    func collectsTheDaysTranscripts() async throws {
        let morning = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 9), status: .completed)
        let evening = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 20), status: .completed)
        let otherDay = Fixtures.recording(at: Fixtures.date(2026, 11, 3, 10), status: .completed)
        let notTranscribed = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 12), status: .pending)
        let sut = makeSUT(recordings: [evening, morning, otherDay, notTranscribed])
        for recording in [morning, evening, otherDay] {
            try addTranscript(sut, for: recording, text: recording.id.uuidString)
        }

        try await sut.useCase.execute(on: Fixtures.date(2026, 11, 4, 22, 30))

        let input = try #require(sut.generator.inputs.first)
        #expect(input.date == Fixtures.date(2026, 11, 4))
        #expect(input.entries.map(\.number) == [1, 2])
        #expect(input.entries.map(\.recordingID) == [morning.id, evening.id])
    }

    @Test("결과를 그 날의 정리로 저장하고 돌려준다")
    func savesDigest() async throws {
        let recording = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 9), status: .completed)
        let sut = makeSUT(recordings: [recording])
        try addTranscript(sut, for: recording)

        let digest = try await sut.useCase.execute(on: Fixtures.date(2026, 11, 4, 22))

        #expect(digest.date == Fixtures.date(2026, 11, 4))
        #expect(digest.diary == Fixtures.sampleContent.diary)
        #expect(digest.todos == Fixtures.sampleContent.todos)
        #expect(digest.model == "fake-model")
        #expect(digest.generatedAt == Fixtures.date(2026, 11, 4, 23, 0))
        #expect(sut.digests.items[digest.date] == digest)
    }

    @Test("같은 날 다시 정리하면 덮어쓴다")
    func regenerateOverwrites() async throws {
        let recording = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 9), status: .completed)
        let sut = makeSUT(recordings: [recording])
        try addTranscript(sut, for: recording)

        try await sut.useCase.execute(on: Fixtures.date(2026, 11, 4))
        sut.generator.result = .success(DigestContent(diary: "다시 쓴 일기", todos: [], decisions: []))
        try await sut.useCase.execute(on: Fixtures.date(2026, 11, 4))

        #expect(sut.digests.items.count == 1)
        #expect(sut.digests.items[Fixtures.date(2026, 11, 4)]?.diary == "다시 쓴 일기")
    }

    @Test("받아쓰기가 없으면 LLM을 부르지 않고 알린다")
    func nothingToDigest() async {
        let sut = makeSUT(recordings: [Fixtures.recording(at: Fixtures.date(2026, 11, 4, 9), status: .pending)])

        await #expect(throws: DigestGenerationError.nothingToDigest) {
            try await sut.useCase.execute(on: Fixtures.date(2026, 11, 4))
        }
        #expect(sut.generator.inputs.isEmpty)
    }

    @Test("생성이 실패하면 기존 정리를 건드리지 않는다")
    func failureKeepsPreviousDigest() async throws {
        let recording = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 9), status: .completed)
        let sut = makeSUT(recordings: [recording])
        try addTranscript(sut, for: recording)
        let first = try await sut.useCase.execute(on: Fixtures.date(2026, 11, 4))

        sut.generator.result = .failure(DigestGenerationError.rateLimited)
        await #expect(throws: DigestGenerationError.rateLimited) {
            try await sut.useCase.execute(on: Fixtures.date(2026, 11, 4))
        }

        #expect(sut.digests.items[first.date] == first)
        #expect(sut.digests.saveCount == 1)
    }

    @Test("FetchDailyDigest는 저장된 정리를 날짜로 찾는다")
    func fetchFindsByDay() throws {
        let digests = InMemoryDigestRepository()
        let digest = DailyDigest(
            date: Fixtures.date(2026, 11, 4), diary: "a", todos: [], decisions: [],
            generatedAt: Fixtures.date(2026, 11, 4, 23), model: "m"
        )
        try digests.save(digest)
        let fetch = FetchDailyDigestUseCase(digests: digests, calendar: Fixtures.seoulCalendar)

        #expect(try fetch.execute(on: Fixtures.date(2026, 11, 4, 15)) == digest)
        #expect(try fetch.execute(on: Fixtures.date(2026, 11, 5)) == nil)
    }
}
