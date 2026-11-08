import Foundation

/// 하루 정리를 `<yyyy-MM-dd>.json`(앱용)과 `<yyyy-MM-dd>.md`(옵시디언용)로 저장한다.
final class FileDigestRepository: DigestRepository {
    private let directory: URL
    private let fileManager: FileManager
    private let formatter: MarkdownDigestFormatter

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
        formatter: MarkdownDigestFormatter = MarkdownDigestFormatter(),
        fileManager: FileManager = .default
    ) throws {
        self.directory = directory
        self.formatter = formatter
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func digest(on date: Date) throws -> DailyDigest? {
        let url = fileURL(for: date, extension: "json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(DailyDigest.self, from: Data(contentsOf: url))
    }

    func save(_ digest: DailyDigest) throws {
        try encoder.encode(digest).write(to: fileURL(for: digest.date, extension: "json"), options: .atomic)
        try Data(formatter.format(digest).utf8).write(to: fileURL(for: digest.date, extension: "md"), options: .atomic)
    }

    private func fileURL(for date: Date, extension ext: String) -> URL {
        directory.appendingPathComponent("\(formatter.dayString(date)).\(ext)")
    }
}
