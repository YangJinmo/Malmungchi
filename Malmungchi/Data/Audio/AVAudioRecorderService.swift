import AVFoundation
import Foundation

/// AVAudioRecorder 기반 녹음기. Whisper 입력에 맞춰 16kHz 모노 AAC로 저장한다.
final class AVAudioRecorderService: NSObject, AudioRecording {
    enum RecorderError: Error, LocalizedError {
        case permissionDenied
        case failedToStart

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "마이크 권한이 필요해요. 설정에서 허용해 주세요."
            case .failedToStart: return "녹음을 시작하지 못했어요."
            }
        }
    }

    private var recorder: AVAudioRecorder?

    var isRecording: Bool { recorder?.isRecording ?? false }
    var currentTime: TimeInterval { recorder?.currentTime ?? 0 }

    func start(to url: URL) async throws {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { throw RecorderError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder.record() else { throw RecorderError.failedToStart }
        self.recorder = recorder
    }

    func stop() -> TimeInterval {
        guard let recorder else { return 0 }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return duration
    }
}
