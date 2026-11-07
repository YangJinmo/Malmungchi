import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let elapsed: TimeInterval
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                Text(isRecording ? DurationText.clock(elapsed) : "녹음 시작")
                    .monospacedDigit()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(isRecording ? Color.red : Color.accentColor, in: Capsule())
        }
        .accessibilityLabel(isRecording ? "녹음 멈추기" : "녹음 시작")
    }
}

/// 재생 버튼, 진행 막대, 15초 앞뒤 이동.
struct PlayerControls: View {
    let isPlaying: Bool
    let time: TimeInterval
    let duration: TimeInterval
    let onToggle: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onSkip: (TimeInterval) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(get: { min(time, max(duration, 0.1)) }, set: onSeek),
                in: 0...max(duration, 0.1)
            )
            .accessibilityLabel("재생 위치")

            HStack {
                Text(DurationText.clock(time))
                Spacer()
                Text(DurationText.clock(duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            HStack(spacing: 36) {
                Button { onSkip(-15) } label: {
                    Image(systemName: "gobackward.15")
                }
                .accessibilityLabel("15초 뒤로")

                Button(action: onToggle) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }
                .accessibilityLabel(isPlaying ? "일시정지" : "재생")

                Button { onSkip(15) } label: {
                    Image(systemName: "goforward.15")
                }
                .accessibilityLabel("15초 앞으로")
            }
            .font(.title2)
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: TranscriptionStatus
    let isTranscribing: Bool

    var body: some View {
        if isTranscribing || status == .inProgress {
            ProgressView()
                .controlSize(.small)
        } else {
            switch status {
            case .pending:
                Image(systemName: "text.badge.plus").foregroundStyle(.secondary)
            case .inProgress:
                ProgressView().controlSize(.small)
            case .completed:
                Image(systemName: "text.badge.checkmark").foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
            }
        }
    }
}

enum DurationText {
    /// 예: "3분 12초", "1시간 5분"
    static func short(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return "\(hours)시간 \(minutes)분" }
        if minutes > 0 { return "\(minutes)분 \(secs)초" }
        return "\(secs)초"
    }

    /// 예: "03:12"
    static func clock(_ seconds: TimeInterval) -> String {
        MarkdownTranscriptFormatter.timestamp(seconds)
    }
}
