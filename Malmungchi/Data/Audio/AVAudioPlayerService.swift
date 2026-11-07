import AVFoundation
import Foundation

/// AVAudioPlayer 기반 재생기. 상세 화면마다 하나씩 만든다.
final class AVAudioPlayerService: NSObject, AudioPlaying, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    var onFinish: (() -> Void)?
    var isPlaying: Bool { player?.isPlaying ?? false }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }

    func load(url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        self.player = player
    }

    func play() {
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(0, time), player.duration)
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        player.currentTime = 0
        onFinish?()
    }
}
