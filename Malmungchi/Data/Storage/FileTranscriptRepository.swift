import Foundation

/// 받아쓰기를 녹음마다 `<id>.json`(앱용)과 `<id>.md`(옵시디언·LLM 위키용)로 저장한다.
final class FileTranscriptRepository: TranscriptRepository {
    private let directory: URL
    private let fileManager: FileManager
    private let formatter: MarkdownTranscriptFormatter

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(
        directory: URL,
        formatter: MarkdownTranscriptFormatter = MarkdownTranscriptFormatter(),
        fileManager: FileManager = .default
    ) throws {
        self.directory = directory
        self.formatter = formatter
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func transcript(for recordingID: UUID) throws -> Transcript? {
        let url = jsonURL(for: recordingID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(Transcript.self, from: Data(contentsOf: url))
    }

    func save(_ transcript: Transcript, for recording: Recording) throws {
        try encoder.encode(transcript).write(to: jsonURL(for: recording.id), options: .atomic)
        let markdown = formatter.format(transcript, recording: recording)
        try Data(markdown.utf8).write(to: markdownURL(for: recording.id), options: .atomic)
    }

    func delete(for recordingID: UUID) throws {
        for url in [jsonURL(for: recordingID), markdownURL(for: recordingID)]
        where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func jsonURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private func markdownURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).md")
    }
}
