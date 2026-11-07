import Foundation
import Observation

@MainActor
@Observable
final class RecordingListViewModel {
    private(set) var days: [RecordingDay] = []
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var transcribingIDs: Set<UUID> = []
    var errorMessage: String?

    /// 녹음·가져오기가 끝나면 바로 받아쓸지
    var autoTranscribe = true

    private let fetchRecordings: FetchRecordingsUseCase
    private let recordAudio: RecordAudioUseCase
    private let importAudioUseCase: ImportAudioUseCase
    private let transcribeRecording: TranscribeRecordingUseCase
    private let deleteRecording: DeleteRecordingUseCase
    private let calendar: Calendar
    private let now: () -> Date
    private var elapsedTask: Task<Void, Never>?

    init(
        fetchRecordings: FetchRecordingsUseCase,
        recordAudio: RecordAudioUseCase,
        importAudio: ImportAudioUseCase,
        transcribeRecording: TranscribeRecordingUseCase,
        deleteRecording: DeleteRecordingUseCase,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.fetchRecordings = fetchRecordings
        self.recordAudio = recordAudio
        self.importAudioUseCase = importAudio
        self.transcribeRecording = transcribeRecording
        self.deleteRecording = deleteRecording
        self.calendar = calendar
        self.now = now
    }

    func load() {
        do {
            days = RecordingGrouper.groupByDay(try fetchRecordings.execute(), calendar: calendar)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    func importAudio(from url: URL) async {
        do {
            let recording = try await importAudioUseCase.execute(from: url)
            load()
            if autoTranscribe {
                await transcribe(recording.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func transcribe(_ id: UUID) async {
        guard !transcribingIDs.contains(id) else { return }
        transcribingIDs.insert(id)
        load()
        do {
            try await transcribeRecording.execute(recordingID: id)
        } catch {
            errorMessage = error.localizedDescription
        }
        transcribingIDs.remove(id)
        load()
    }

    func delete(_ id: UUID) {
        do {
            try deleteRecording.execute(recordingID: id)
        } catch {
            errorMessage = error.localizedDescription
        }
        load()
    }

    // MARK: - Recording

    private func startRecording() async {
        do {
            try await recordAudio.start()
            isRecording = true
            elapsed = 0
            startElapsedUpdates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopRecording() async {
        elapsedTask?.cancel()
        elapsedTask = nil
        isRecording = false
        do {
            let recording = try recordAudio.stop(title: Self.defaultTitle(for: now(), timeZone: calendar.timeZone))
            load()
            if autoTranscribe {
                await transcribe(recording.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startElapsedUpdates() {
        elapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { return }
                self.elapsed = self.recordAudio.elapsed
            }
        }
    }

    static func defaultTitle(
        for date: Date,
        timeZone: TimeZone = .current,
        locale: Locale = Locale(identifier: "ko_KR")
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "a h:mm 녹음"
        return formatter.string(from: date)
    }
}
