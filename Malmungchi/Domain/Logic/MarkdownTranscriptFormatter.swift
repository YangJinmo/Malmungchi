import Foundation

/// 받아쓰기를 옵시디언 호환 마크다운으로 바꾼다. 3주 차 LLM 위키의 원자료가 된다.
struct MarkdownTranscriptFormatter {
    var timeZone: TimeZone = .current

    func format(_ transcript: Transcript, recording: Recording) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = timeZone
        dateFormatter.formatOptions = [.withInternetDateTime]

        var lines: [String] = [
            "---",
            "id: \(recording.id.uuidString)",
            "date: \(dateFormatter.string(from: recording.createdAt))",
            "duration: \(Int(recording.duration.rounded()))",
            "source: \(recording.source.rawValue)",
            "language: \(transcript.language)",
            "---",
            "",
            "# \(recording.title.isEmpty ? "녹음" : recording.title)",
            "",
        ]

        for segment in transcript.segments {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            lines.append("[\(Self.timestamp(segment.start))] \(text)")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// 1시간 미만은 `mm:ss`, 이상은 `h:mm:ss`.
    static func timestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
