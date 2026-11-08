import Foundation

/// 하루 정리를 옵시디언 호환 마크다운으로 바꾼다.
/// 출처는 `[[<녹음 id>|mm:ss]]` 위키링크라서 `Transcripts/<id>.md`로 이어진다.
struct MarkdownDigestFormatter {
    var timeZone: TimeZone = .current

    /// 파일 이름과 제목에 쓰는 날짜. 예: "2026-11-04"
    func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func format(_ digest: DailyDigest) -> String {
        let iso = ISO8601DateFormatter()
        iso.timeZone = timeZone
        iso.formatOptions = [.withInternetDateTime]

        var lines: [String] = [
            "---",
            "date: \(dayString(digest.date))",
            "generated: \(iso.string(from: digest.generatedAt))",
            "model: \(digest.model)",
            "todos: \(digest.todos.count)",
            "decisions: \(digest.decisions.count)",
            "---",
            "",
            "# \(dayString(digest.date)) 하루 정리",
            "",
            "## 일기",
            "",
            digest.diary,
            "",
            "## 할 일",
            "",
        ]

        if digest.todos.isEmpty {
            lines.append("_없어요_")
        } else {
            for todo in digest.todos {
                var line = "- [ ] \(Self.singleLine(todo.text))"
                if let due = todo.due { line += " (\(Self.singleLine(due)))" }
                if let source = todo.source { line += " \(Self.link(source))" }
                lines.append(line)
            }
        }

        lines += ["", "## 결정 사항", ""]

        if digest.decisions.isEmpty {
            lines.append("_없어요_")
        } else {
            for decision in digest.decisions {
                var line = "- \(Self.singleLine(decision.text))"
                if let source = decision.source { line += " \(Self.link(source))" }
                lines.append(line)
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func link(_ source: DigestSource) -> String {
        let label = source.time.map(MarkdownTranscriptFormatter.timestamp) ?? "녹음"
        return "[[\(source.recordingID.uuidString)|\(label)]]"
    }

    /// 목록 항목 안에서 줄이 바뀌면 목록이 깨지므로 한 줄로 만든다.
    private static func singleLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
