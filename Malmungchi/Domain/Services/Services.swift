import Foundation

/// 마이크 녹음기.
protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    /// 현재 녹음 경과 시간(초).
    var currentTime: TimeInterval { get }
    func start(to url: URL) async throws
    /// 녹음을 멈추고 녹음된 길이(초)를 돌려준다.
    func stop() -> TimeInterval
}

/// 오디오 재생기.
protocol AudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    /// 현재 재생 위치(초)
    var currentTime: TimeInterval { get }
    /// 불러온 파일의 전체 길이(초). 불러오기 전이면 0.
    var duration: TimeInterval { get }
    /// 끝까지 재생되면 호출된다.
    var onFinish: (() -> Void)? { get set }
    func load(url: URL) throws
    func play()
    func pause()
    func seek(to time: TimeInterval)
}

/// 음성 → 텍스트 엔진. 구현체는 기기 안에서 동작한다 (WhisperKit).
protocol Transcribing {
    func transcribe(audioURL: URL, language: String) async throws -> TranscriptionOutput
}

/// 공유 시트로 보내 온 오디오 파일이 가져가기를 기다리는 곳.
protocol SharedAudioInbox: AnyObject {
    /// 대기 중인 파일. 오래된 것부터.
    func pendingFiles() throws -> [URL]
    /// 가져온 파일을 지운다.
    func remove(_ file: URL) throws
}
