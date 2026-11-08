import Foundation
@testable import Malmungchi

struct StubError: Error, LocalizedError {
    var errorDescription: String? { "stub failure" }
}

final class InMemoryRecordingRepository: RecordingRepository {
    private(set) var items: [UUID: Recording] = [:]
    /// 저장된 순서대로의 기록. 상태 전이를 검증할 때 쓴다.
    private(set) var saveHistory: [Recording] = []

    init(_ recordings: [Recording] = []) {
        recordings.forEach { items[$0.id] = $0 }
    }

    func fetchAll() throws -> [Recording] {
        items.values.sorted { $0.createdAt > $1.createdAt }
    }

    func recording(id: UUID) throws -> Recording? {
        items[id]
    }

    func save(_ recording: Recording) throws {
        items[recording.id] = recording
        saveHistory.append(recording)
    }

    func delete(id: UUID) throws {
        items[id] = nil
    }
}

final class InMemoryTranscriptRepository: TranscriptRepository {
    private(set) var items: [UUID: Transcript] = [:]

    func transcript(for recordingID: UUID) throws -> Transcript? {
        items[recordingID]
    }

    func save(_ transcript: Transcript, for recording: Recording) throws {
        items[recording.id] = transcript
    }

    func delete(for recordingID: UUID) throws {
        items[recordingID] = nil
    }
}

final class FakeAudioStorage: AudioStorage {
    var nextFileName = "fake.m4a"
    var durationToReturn: TimeInterval = 42
    private(set) var files: Set<String> = []
    private(set) var importedSources: [URL] = []

    func makeRecordingFileName() -> String {
        nextFileName
    }

    func url(for fileName: String) -> URL {
        URL(fileURLWithPath: "/fake/\(fileName)")
    }

    func importFile(from sourceURL: URL) throws -> String {
        importedSources.append(sourceURL)
        files.insert(nextFileName)
        return nextFileName
    }

    func duration(of fileName: String) async throws -> TimeInterval {
        durationToReturn
    }

    func remove(fileName: String) throws {
        files.remove(fileName)
    }

    func addFile(_ fileName: String) {
        files.insert(fileName)
    }
}

final class FakeAudioRecorder: AudioRecording {
    var startError: Error?
    var durationToReturn: TimeInterval = 30
    private(set) var startedURL: URL?
    private(set) var isRecording = false
    var currentTime: TimeInterval = 0

    func start(to url: URL) async throws {
        if let startError { throw startError }
        startedURL = url
        isRecording = true
    }

    func stop() -> TimeInterval {
        isRecording = false
        return durationToReturn
    }
}

final class FakeTranscriber: Transcribing {
    var result: Result<TranscriptionOutput, Error>
    private(set) var requestedURLs: [URL] = []
    private(set) var requestedLanguages: [String] = []

    init(result: Result<TranscriptionOutput, Error>) {
        self.result = result
    }

    func transcribe(audioURL: URL, language: String) async throws -> TranscriptionOutput {
        requestedURLs.append(audioURL)
        requestedLanguages.append(language)
        return try result.get()
    }
}

enum Fixtures {
    static let seoul = TimeZone(identifier: "Asia/Seoul")!

    static var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoul
        return calendar
    }

    /// 서울 시각 기준 날짜
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        seoulCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func recording(
        at date: Date,
        title: String = "테스트",
        duration: TimeInterval = 60,
        source: RecordingSource = .inApp,
        status: TranscriptionStatus = .pending
    ) -> Recording {
        Recording(
            createdAt: date,
            fileName: "\(UUID().uuidString).m4a",
            title: title,
            duration: duration,
            source: source,
            status: status
        )
    }

    static let sampleOutput = TranscriptionOutput(
        language: "ko",
        segments: [
            TranscriptSegment(start: 5, end: 9, text: "다음 주 월요일에 통화하기로 했어요."),
            TranscriptSegment(start: 0, end: 4, text: "안녕하세요."),
        ]
    )
}

final class FakeAudioPlayer: AudioPlaying {
    var loadError: Error?
    var durationToReport: TimeInterval = 120
    private(set) var loadedURLs: [URL] = []
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var isLoaded = false
    var onFinish: (() -> Void)?

    var duration: TimeInterval { isLoaded ? durationToReport : 0 }

    func load(url: URL) throws {
        if let loadError { throw loadError }
        loadedURLs.append(url)
        isLoaded = true
    }

    func play() { isPlaying = isLoaded }
    func pause() { isPlaying = false }

    func seek(to time: TimeInterval) {
        currentTime = min(max(0, time), durationToReport)
    }

    /// 재생기가 끝까지 재생한 상황을 흉내 낸다.
    func simulateFinish() {
        isPlaying = false
        currentTime = 0
        onFinish?()
    }
}

final class InMemoryAppSettings: AppSettings {
    var transcriptionModel: TranscriptionModel

    init(transcriptionModel: TranscriptionModel = .base) {
        self.transcriptionModel = transcriptionModel
    }
}

final class InMemoryDigestRepository: DigestRepository {
    private(set) var items: [Date: DailyDigest] = [:]
    private(set) var saveCount = 0
    var saveError: Error?

    func digest(on date: Date) throws -> DailyDigest? {
        items[date]
    }

    func save(_ digest: DailyDigest) throws {
        if let saveError { throw saveError }
        items[digest.date] = digest
        saveCount += 1
    }
}

final class InMemoryAPIKeyStore: APIKeyStoring {
    private(set) var key: String?
    var failure: Error?

    init(key: String? = nil) {
        self.key = key
    }

    func load() throws -> String? {
        if let failure { throw failure }
        return key
    }

    func save(_ key: String) throws {
        if let failure { throw failure }
        self.key = key
    }

    func delete() throws {
        if let failure { throw failure }
        key = nil
    }
}

final class FakeDigestGenerator: DailyDigestGenerating {
    var result: Result<DigestContent, Error>
    var modelName = "fake-model"
    private(set) var inputs: [DigestInput] = []

    init(result: Result<DigestContent, Error> = .success(Fixtures.sampleContent)) {
        self.result = result
    }

    func generate(from input: DigestInput) async throws -> DigestContent {
        inputs.append(input)
        return try result.get()
    }
}

extension Fixtures {
    static let sampleContent = DigestContent(
        diary: "오늘은 견적 이야기를 했다.",
        todos: [DigestTodo(text: "견적서 보내기", due: "금요일")],
        decisions: [DigestDecision(text: "디자인은 외주로 한다", source: nil)]
    )
}
