import Foundation
import Testing
@testable import Malmungchi

@Suite("ImportAudioUseCase")
struct ImportAudioUseCaseTests {
    @Test("가져온 파일을 저장하고 파일 이름을 제목으로 쓴다")
    func importsFileAndSavesRecording() async throws {
        let storage = FakeAudioStorage()
        storage.nextFileName = "imported.m4a"
        storage.durationToReturn = 754
        let repository = InMemoryRecordingRepository()
        let now = Fixtures.date(2026, 11, 4, 21, 0)
        let useCase = ImportAudioUseCase(storage: storage, repository: repository, now: { now })

        let source = URL(fileURLWithPath: "/tmp/통화 녹음 261030_085308.m4a")
        let recording = try await useCase.execute(from: source)

        #expect(recording.fileName == "imported.m4a")
        #expect(recording.title == "통화 녹음 261030_085308")
        #expect(recording.duration == 754)
        #expect(recording.source == .imported)
        #expect(recording.status == .pending)
        #expect(recording.createdAt == now)
        #expect(try repository.recording(id: recording.id) == recording)
        #expect(storage.importedSources == [source])
    }
}

@Suite("RecordAudioUseCase")
struct RecordAudioUseCaseTests {
    @Test("녹음을 멈추면 시작 시각과 길이로 기록을 만든다")
    func stopCreatesRecording() async throws {
        let recorder = FakeAudioRecorder()
        recorder.durationToReturn = 95
        let storage = FakeAudioStorage()
        storage.nextFileName = "new.m4a"
        let repository = InMemoryRecordingRepository()
        let startedAt = Fixtures.date(2026, 11, 4, 9, 30)
        let useCase = RecordAudioUseCase(recorder: recorder, storage: storage, repository: repository, now: { startedAt })

        try await useCase.start()
        #expect(useCase.isRecording)
        #expect(recorder.startedURL == storage.url(for: "new.m4a"))

        let recording = try useCase.stop(title: "오전 9:30 녹음")

        #expect(!useCase.isRecording)
        #expect(recording.createdAt == startedAt)
        #expect(recording.duration == 95)
        #expect(recording.source == .inApp)
        #expect(recording.fileName == "new.m4a")
        #expect(try repository.fetchAll().count == 1)
    }

    @Test("녹음 중에 다시 시작하면 실패한다")
    func startTwiceFails() async throws {
        let useCase = RecordAudioUseCase(
            recorder: FakeAudioRecorder(),
            storage: FakeAudioStorage(),
            repository: InMemoryRecordingRepository()
        )
        try await useCase.start()
        await #expect(throws: DomainError.alreadyRecording) {
            try await useCase.start()
        }
    }

    @Test("녹음 중이 아닐 때 멈추면 실패한다")
    func stopWithoutStartFails() {
        let useCase = RecordAudioUseCase(
            recorder: FakeAudioRecorder(),
            storage: FakeAudioStorage(),
            repository: InMemoryRecordingRepository()
        )
        #expect(throws: DomainError.notRecording) {
            try useCase.stop(title: "")
        }
    }

    @Test("녹음기 시작이 실패하면 녹음 중 상태가 되지 않는다")
    func recorderFailureKeepsIdle() async {
        let recorder = FakeAudioRecorder()
        recorder.startError = StubError()
        let useCase = RecordAudioUseCase(
            recorder: recorder,
            storage: FakeAudioStorage(),
            repository: InMemoryRecordingRepository()
        )
        await #expect(throws: StubError.self) {
            try await useCase.start()
        }
        #expect(!useCase.isRecording)
    }
}

@Suite("TranscribeRecordingUseCase")
struct TranscribeRecordingUseCaseTests {
    private func makeSUT(
        recording: Recording,
        result: Result<TranscriptionOutput, Error>
    ) -> (TranscribeRecordingUseCase, InMemoryRecordingRepository, InMemoryTranscriptRepository, FakeTranscriber) {
        let recordings = InMemoryRecordingRepository([recording])
        let transcripts = InMemoryTranscriptRepository()
        let transcriber = FakeTranscriber(result: result)
        let useCase = TranscribeRecordingUseCase(
            recordings: recordings,
            transcripts: transcripts,
            storage: FakeAudioStorage(),
            transcriber: transcriber,
            now: { Fixtures.date(2026, 11, 4, 22) }
        )
        return (useCase, recordings, transcripts, transcriber)
    }

    @Test("성공하면 구간을 시간순으로 저장하고 상태를 inProgress → completed로 바꾼다")
    func successStoresTranscript() async throws {
        let recording = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 9))
        let (useCase, recordings, transcripts, transcriber) = makeSUT(
            recording: recording,
            result: .success(Fixtures.sampleOutput)
        )

        let transcript = try await useCase.execute(recordingID: recording.id)

        #expect(transcript.segments.map(\.start) == [0, 5])
        #expect(transcript.text == "안녕하세요. 다음 주 월요일에 통화하기로 했어요.")
        #expect(try transcripts.transcript(for: recording.id) == transcript)
        #expect(recordings.saveHistory.map(\.status) == [.inProgress, .completed])
        #expect(transcriber.requestedLanguages == ["ko"])
    }

    @Test("실패하면 상태를 failed로 남기고 에러를 다시 던진다")
    func failureMarksFailed() async throws {
        let recording = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 9))
        let (useCase, recordings, transcripts, _) = makeSUT(recording: recording, result: .failure(StubError()))

        await #expect(throws: StubError.self) {
            try await useCase.execute(recordingID: recording.id)
        }

        #expect(try recordings.recording(id: recording.id)?.status == .failed(message: "stub failure"))
        #expect(try transcripts.transcript(for: recording.id) == nil)
    }

    @Test("없는 녹음이면 recordingNotFound")
    func missingRecording() async {
        let (useCase, _, _, transcriber) = makeSUT(
            recording: Fixtures.recording(at: .now),
            result: .success(Fixtures.sampleOutput)
        )
        await #expect(throws: DomainError.recordingNotFound) {
            try await useCase.execute(recordingID: UUID())
        }
        #expect(transcriber.requestedURLs.isEmpty)
    }
}

@Suite("DeleteRecordingUseCase")
struct DeleteRecordingUseCaseTests {
    @Test("오디오, 받아쓰기, 메타데이터를 모두 지운다")
    func deletesEverything() throws {
        let recording = Fixtures.recording(at: .now)
        let recordings = InMemoryRecordingRepository([recording])
        let transcripts = InMemoryTranscriptRepository()
        try transcripts.save(
            Transcript(recordingID: recording.id, language: "ko", segments: [], createdAt: .now),
            for: recording
        )
        let storage = FakeAudioStorage()
        storage.addFile(recording.fileName)

        try DeleteRecordingUseCase(recordings: recordings, transcripts: transcripts, storage: storage)
            .execute(recordingID: recording.id)

        #expect(try recordings.recording(id: recording.id) == nil)
        #expect(try transcripts.transcript(for: recording.id) == nil)
        #expect(!storage.files.contains(recording.fileName))
    }
}
