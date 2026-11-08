import Foundation

struct FetchRecordingsUseCase {
    let repository: RecordingRepository

    func execute() throws -> [Recording] {
        try repository.fetchAll()
    }
}

/// 앱 안에서 녹음을 시작하고 끝낸다.
final class RecordAudioUseCase {
    private let recorder: AudioRecording
    private let storage: AudioStorage
    private let repository: RecordingRepository
    private let now: () -> Date
    private var activeFileName: String?
    private var startedAt: Date?

    init(
        recorder: AudioRecording,
        storage: AudioStorage,
        repository: RecordingRepository,
        now: @escaping () -> Date = Date.init
    ) {
        self.recorder = recorder
        self.storage = storage
        self.repository = repository
        self.now = now
    }

    var isRecording: Bool { activeFileName != nil }
    var elapsed: TimeInterval { recorder.currentTime }

    func start() async throws {
        guard activeFileName == nil else { throw DomainError.alreadyRecording }
        let fileName = storage.makeRecordingFileName()
        try await recorder.start(to: storage.url(for: fileName))
        activeFileName = fileName
        startedAt = now()
    }

    /// - Parameter title: 비워두면 호출하는 쪽에서 표시용 제목을 정한다.
    @discardableResult
    func stop(title: String) throws -> Recording {
        guard let fileName = activeFileName, let startedAt else { throw DomainError.notRecording }
        let duration = recorder.stop()
        activeFileName = nil
        self.startedAt = nil

        let recording = Recording(
            createdAt: startedAt,
            fileName: fileName,
            title: title,
            duration: duration,
            source: .inApp
        )
        try repository.save(recording)
        return recording
    }
}

/// 통화 녹음, 음성 메모 같은 외부 오디오 파일을 가져온다.
struct ImportAudioUseCase {
    let storage: AudioStorage
    let repository: RecordingRepository
    var now: () -> Date = Date.init

    func execute(from sourceURL: URL) async throws -> Recording {
        let fileName = try storage.importFile(from: sourceURL)
        let duration = (try? await storage.duration(of: fileName)) ?? 0
        let recording = Recording(
            createdAt: now(),
            fileName: fileName,
            title: sourceURL.deletingPathExtension().lastPathComponent,
            duration: duration,
            source: .imported
        )
        try repository.save(recording)
        return recording
    }
}

/// 녹음을 받아쓰고 결과를 저장한다. 상태는 pending → inProgress → completed / failed 로 바뀐다.
struct TranscribeRecordingUseCase {
    let recordings: RecordingRepository
    let transcripts: TranscriptRepository
    let storage: AudioStorage
    let transcriber: Transcribing
    var language: String = "ko"
    var now: () -> Date = Date.init

    @discardableResult
    func execute(recordingID: UUID) async throws -> Transcript {
        guard var recording = try recordings.recording(id: recordingID) else {
            throw DomainError.recordingNotFound
        }

        recording.status = .inProgress
        try recordings.save(recording)

        do {
            let output = try await transcriber.transcribe(
                audioURL: storage.url(for: recording.fileName),
                language: language
            )
            let transcript = Transcript(
                recordingID: recording.id,
                language: output.language,
                segments: output.segments.sorted { $0.start < $1.start },
                createdAt: now()
            )
            try transcripts.save(transcript, for: recording)

            recording.status = .completed
            try recordings.save(recording)
            return transcript
        } catch {
            recording.status = .failed(message: error.localizedDescription)
            try? recordings.save(recording)
            throw error
        }
    }
}

struct FetchTranscriptUseCase {
    let transcripts: TranscriptRepository

    func execute(recordingID: UUID) throws -> Transcript? {
        try transcripts.transcript(for: recordingID)
    }
}

/// 오디오 파일, 받아쓰기, 메타데이터를 모두 지운다.
struct DeleteRecordingUseCase {
    let recordings: RecordingRepository
    let transcripts: TranscriptRepository
    let storage: AudioStorage

    func execute(recordingID: UUID) throws {
        guard let recording = try recordings.recording(id: recordingID) else {
            throw DomainError.recordingNotFound
        }
        try storage.remove(fileName: recording.fileName)
        try transcripts.delete(for: recordingID)
        try recordings.delete(id: recordingID)
    }
}

struct SharedImportResult: Equatable {
    let imported: [Recording]
    /// 가져오지 못해 Inbox에 남겨 둔 파일 수
    let failedCount: Int
}

/// 공유 시트로 받은 오디오를 모두 가져오고 Inbox를 비운다.
/// 하나가 실패해도 나머지는 계속하고, 실패한 파일은 남겨서 다음에 다시 시도한다.
struct ImportSharedAudioUseCase {
    let inbox: SharedAudioInbox
    let importAudio: ImportAudioUseCase

    func execute() async throws -> SharedImportResult {
        var imported: [Recording] = []
        var failed = 0

        for file in try inbox.pendingFiles() {
            do {
                imported.append(try await importAudio.execute(from: file))
            } catch {
                failed += 1
                continue
            }
            // 가져온 뒤에는 지우지 못해도 실패로 세지 않는다 (다시 가져오면 중복이 되므로).
            try? inbox.remove(file)
        }
        return SharedImportResult(imported: imported, failedCount: failed)
    }
}
