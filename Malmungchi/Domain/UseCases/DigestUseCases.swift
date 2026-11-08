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
