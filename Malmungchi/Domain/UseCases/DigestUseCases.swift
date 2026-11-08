import Foundation

/// 하루치 받아쓰기를 모아 LLM으로 정리하고 저장한다. 같은 날 다시 하면 덮어쓴다.
struct GenerateDailyDigestUseCase {
    let recordings: RecordingRepository
    let transcripts: TranscriptRepository
    let digests: DigestRepository
    let generator: DailyDigestGenerating
    var calendar: Calendar = .current
    var now: () -> Date = Date.init

    /// - Parameter date: 정리할 날. 시각은 무시하고 `calendar` 기준 그 날로 본다.
    @discardableResult
    func execute(on date: Date) async throws -> DailyDigest {
        let day = calendar.startOfDay(for: date)

        let entries = try recordings.fetchAll()
            .filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { recording -> (Recording, Transcript)? in
                guard let transcript = try transcripts.transcript(for: recording.id), !transcript.segments.isEmpty else {
                    return nil
                }
                return (recording, transcript)
            }
            .enumerated()
            .map { offset, pair in
                DigestInput.Entry(
                    number: offset + 1,
                    recordingID: pair.0.id,
                    startedAt: pair.0.createdAt,
                    segments: pair.1.segments
                )
            }

        guard !entries.isEmpty else { throw DigestGenerationError.nothingToDigest }

        let content = try await generator.generate(from: DigestInput(date: day, entries: entries))
        let digest = DailyDigest(
            date: day,
            diary: content.diary,
            todos: content.todos,
            decisions: content.decisions,
            generatedAt: now(),
            model: generator.modelName
        )
        try digests.save(digest)
        return digest
    }
}

struct FetchDailyDigestUseCase {
    let digests: DigestRepository
    var calendar: Calendar = .current

    func execute(on date: Date) throws -> DailyDigest? {
        try digests.digest(on: calendar.startOfDay(for: date))
    }
}

/// 사용자가 고른 할 일만 미리알림에 넣는다. 자동으로 넣지 않는다.
struct AddTodosToRemindersUseCase {
    let reminders: ReminderAdding
    let digests: DigestRepository
    var dayFormatter = MarkdownDigestFormatter()

    /// - Returns: 미리알림에 넣은 내용이 반영된 정리. 이미 넣은 할 일은 건너뛴다.
    /// 중간에 실패하면 그때까지 넣은 것은 기록하고 에러를 던진다.
    func execute(todoIDs: Set<UUID>, in digest: DailyDigest) async throws -> DailyDigest {
        let pending = digest.todos.filter { todoIDs.contains($0.id) && !digest.remindedTodoIDs.contains($0.id) }
        guard !pending.isEmpty else { return digest }

        switch reminders.access {
        case .granted: break
        case .denied: throw ReminderError.accessDenied
        case .notDetermined:
            guard try await reminders.requestAccess() else { throw ReminderError.accessDenied }
        }

        var updated = digest
        var failure: Error?
        for todo in pending {
            do {
                try reminders.add(NewReminder(title: todo.text, notes: notes(for: todo, in: digest)))
                updated.remindedTodoIDs.insert(todo.id)
            } catch {
                failure = error
                break
            }
        }

        if updated != digest { try digests.save(updated) }
        if let failure { throw failure }
        return updated
    }

    private func notes(for todo: DigestTodo, in digest: DailyDigest) -> String {
        var lines: [String] = []
        if let due = todo.due { lines.append("기한: \(due)") }
        lines.append("말뭉치 \(dayFormatter.dayString(digest.date)) 하루 정리")
        return lines.joined(separator: "\n")
    }
}
