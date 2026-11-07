import Foundation

/// 녹음 메타데이터를 JSON 파일 하나에 저장한다.
/// 파일이 손상되면 조용히 버리지 않고 백업한 뒤 에러로 알린다.
final class JSONRecordingRepository: RecordingRepository {
    enum RepositoryError: Error, LocalizedError {
        case corrupted(backupURL: URL)

        var errorDescription: String? {
            switch self {
            case .corrupted(let backupURL):
                return "녹음 목록 파일이 손상돼 백업했어요: \(backupURL.lastPathComponent)"
            }
        }
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()
    private var cache: [Recording]?

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

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func fetchAll() throws -> [Recording] {
        lock.lock()
        defer { lock.unlock() }
        return try load().sorted { $0.createdAt > $1.createdAt }
    }

    func recording(id: UUID) throws -> Recording? {
        lock.lock()
        defer { lock.unlock() }
        return try load().first { $0.id == id }
    }

    func save(_ recording: Recording) throws {
        lock.lock()
        defer { lock.unlock() }
        var all = try load()
        if let index = all.firstIndex(where: { $0.id == recording.id }) {
            all[index] = recording
        } else {
            all.append(recording)
        }
        try write(all)
    }

    func delete(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        var all = try load()
        all.removeAll { $0.id == id }
        try write(all)
    }

    // MARK: - Private

    private func load() throws -> [Recording] {
        if let cache { return cache }
        guard fileManager.fileExists(atPath: fileURL.path) else {
            cache = []
            return []
        }

        let data = try Data(contentsOf: fileURL)
        do {
            let recordings = try decoder.decode([Recording].self, from: data)
            cache = recordings
            return recordings
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backupURL = fileURL
                .deletingPathExtension()
                .appendingPathExtension("corrupt-\(stamp).json")
            try? fileManager.moveItem(at: fileURL, to: backupURL)
            cache = []
            throw RepositoryError.corrupted(backupURL: backupURL)
        }
    }

    private func write(_ recordings: [Recording]) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(recordings)
        try data.write(to: fileURL, options: .atomic)
        cache = recordings
    }
}
