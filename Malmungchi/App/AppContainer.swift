import Foundation

/// 의존성 조립 지점 (Composition Root). 여기서만 구체 타입을 안다.
final class AppContainer {
    let recordings: RecordingRepository
    let transcripts: TranscriptRepository
    let storage: AudioStorage
    let recorder: AudioRecording
    let transcriber: Transcribing
    let settings: AppSettings
    let apiKeys: APIKeyStoring
    let digests: DigestRepository
    let digestGenerator: DailyDigestGenerating
    let reminders: ReminderAdding

    init(
        recordings: RecordingRepository,
        transcripts: TranscriptRepository,
        storage: AudioStorage,
        recorder: AudioRecording,
        transcriber: Transcribing,
        settings: AppSettings,
        apiKeys: APIKeyStoring,
        digests: DigestRepository,
        digestGenerator: DailyDigestGenerating,
        reminders: ReminderAdding
    ) {
        self.recordings = recordings
        self.transcripts = transcripts
        self.storage = storage
        self.recorder = recorder
        self.transcriber = transcriber
        self.settings = settings
        self.apiKeys = apiKeys
        self.digests = digests
        self.digestGenerator = digestGenerator
        self.reminders = reminders
    }

    /// Documents/Malmungchi 아래에 Audio, Transcripts, recordings.json을 둔다.
    /// 파일 앱에서 보이므로 나중에 옵시디언 볼트로 그대로 열 수 있다.
    static func live(fileManager: FileManager = .default) throws -> AppContainer {
        let documents = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let settings = UserDefaultsAppSettings()
        let apiKeys = KeychainAPIKeyStore()
        let root = documents.appendingPathComponent("Malmungchi", isDirectory: true)

        return AppContainer(
            recordings: JSONRecordingRepository(fileURL: root.appendingPathComponent("recordings.json")),
            transcripts: try FileTranscriptRepository(directory: root.appendingPathComponent("Transcripts", isDirectory: true)),
            storage: try FileAudioStorage(directory: root.appendingPathComponent("Audio", isDirectory: true)),
            recorder: AVAudioRecorderService(),
            transcriber: WhisperKitTranscriber(modelProvider: { settings.transcriptionModel }),
            settings: settings,
            apiKeys: apiKeys,
            digests: try FileDigestRepository(directory: root.appendingPathComponent("Digests", isDirectory: true)),
            digestGenerator: ClaudeDigestGenerator(apiKeys: apiKeys),
            reminders: EventKitReminderService()
        )
    }

    private var transcribeUseCase: TranscribeRecordingUseCase {
        TranscribeRecordingUseCase(
            recordings: recordings,
            transcripts: transcripts,
            storage: storage,
            transcriber: transcriber
        )
    }

    @MainActor
    func makeListViewModel() -> RecordingListViewModel {
        RecordingListViewModel(
            fetchRecordings: FetchRecordingsUseCase(repository: recordings),
            recordAudio: RecordAudioUseCase(recorder: recorder, storage: storage, repository: recordings),
            importAudio: ImportAudioUseCase(storage: storage, repository: recordings),
            transcribeRecording: transcribeUseCase,
            deleteRecording: DeleteRecordingUseCase(recordings: recordings, transcripts: transcripts, storage: storage)
        )
    }

    @MainActor
    func makeDigestViewModel(for date: Date) -> DailyDigestViewModel {
        DailyDigestViewModel(
            date: date,
            fetchDigest: FetchDailyDigestUseCase(digests: digests),
            generateDigest: GenerateDailyDigestUseCase(
                recordings: recordings,
                transcripts: transcripts,
                digests: digests,
                generator: digestGenerator
            ),
            addTodos: AddTodosToRemindersUseCase(reminders: reminders, digests: digests)
        )
    }

    @MainActor
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(settings: settings, apiKeys: apiKeys)
    }

    @MainActor
    func makeDetailViewModel(for recording: Recording) -> RecordingDetailViewModel {
        RecordingDetailViewModel(
            recording: recording,
            recordings: recordings,
            fetchTranscript: FetchTranscriptUseCase(transcripts: transcripts),
            transcribeRecording: transcribeUseCase,
            storage: storage,
            player: AVAudioPlayerService()
        )
    }
}
