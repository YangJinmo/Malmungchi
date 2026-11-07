// xcode: set sdk=iOS

import Foundation
import Observation

@MainActor
@Observable
final class RecordingDetailViewModel {
    private(set) var recording: Recording
    private(set) var transcript: Transcript?
    private(set) var isTranscribing = false
    var errorMessage: String?

    // MARK: Playback state
    private(set) var isPlaying = false
    private(set) var playbackTime: TimeInterval = 0
    private(set) var playbackDuration: TimeInterval

    private let recordings: RecordingRepository
    private let fetchTranscript: FetchTranscriptUseCase
    private let transcribeRecording: TranscribeRecordingUseCase
    private let storage: AudioStorage
    private let player: AudioPlaying
    private let formatter: MarkdownTranscriptFormatter
    private var isPlayerLoaded = false
    private var progressTask: Task<Void, Never>?

    init(
        recording: Recording,
        recordings: RecordingRepository,
        fetchTranscript: FetchTranscriptUseCase,
        transcribeRecording: TranscribeRecordingUseCase,
        storage: AudioStorage,
        player: AudioPlaying,
        formatter: MarkdownTranscriptFormatter = MarkdownTranscriptFormatter()
    ) {
        self.recording = recording
        self.recordings = recordings
        self.fetchTranscript = fetchTranscript
        self.transcribeRecording = transcribeRecording
        self.storage = storage
        self.player = player
        self.formatter = formatter
        self.playbackDuration = recording.duration
    }

    /// 공유용 마크다운. 받아쓰기 전이면 nil.
    var markdown: String? {
        transcript.map { formatter.format($0, recording: recording) }
    }

    /// 지금 재생 중인 위치의 받아쓰기 구간. 재생을 시작한 적이 없으면 nil.
    var currentSegmentIndex: Int? {
        guard isPlayerLoaded else { return nil }
        return transcript?.segmentIndex(at: playbackTime)
    }

    func load() {
        do {
            if let latest = try recordings.recording(id: recording.id) {
                recording = latest
            }
            transcript = try fetchTranscript.execute(recordingID: recording.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func transcribe() async {
        guard !isTranscribing else { return }
        isTranscribing = true
        do {
            transcript = try await transcribeRecording.execute(recordingID: recording.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isTranscribing = false
        load()
    }

    // MARK: - Playback

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard prepareIfNeeded() else { return }
        player.play()
        isPlaying = player.isPlaying
        startProgressUpdates()
    }

    func pause() {
        player.pause()
        isPlaying = false
        playbackTime = player.currentTime
        stopProgressUpdates()
    }

    func seek(to time: TimeInterval) {
        guard prepareIfNeeded() else { return }
        player.seek(to: time)
        playbackTime = player.currentTime
    }

    /// 현재 위치에서 앞뒤로 이동. 예: -15, +15
    func skip(by seconds: TimeInterval) {
        seek(to: playbackTime + seconds)
    }

    /// 받아쓰기 구간을 누르면 그 위치부터 재생한다.
    func play(from segment: TranscriptSegment) {
        seek(to: segment.start)
        play()
    }

    /// 화면을 떠날 때 호출
    func stopPlayback() {
        if isPlaying { pause() }
    }

    /// 재생기가 끝까지 재생했을 때. 재생기 콜백과 테스트에서 부른다.
    func handlePlaybackFinished() {
        isPlaying = false
        playbackTime = 0
        stopProgressUpdates()
    }

    private func prepareIfNeeded() -> Bool {
        if isPlayerLoaded { return true }
        do {
            try player.load(url: storage.url(for: recording.fileName))
            player.onFinish = { [weak self] in
                Task { @MainActor in self?.handlePlaybackFinished() }
            }
            if player.duration > 0 {
                playbackDuration = player.duration
            }
            isPlayerLoaded = true
            return true
        } catch {
            errorMessage = "녹음 파일을 재생할 수 없어요: \(error.localizedDescription)"
            return false
        }
    }

    private func startProgressUpdates() {
        stopProgressUpdates()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                self.playbackTime = self.player.currentTime
            }
        }
    }

    private func stopProgressUpdates() {
        progressTask?.cancel()
        progressTask = nil
    }
}
