import AVFoundation
import Foundation

/// 앱 Documents/Malmungchi/Audio 폴더에 오디오 파일을 둔다. 파일 앱에서도 보인다.
final class FileAudioStorage: AudioStorage {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) throws {
        self.directory = directory
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func makeRecordingFileName() -> String {
        "\(UUID().uuidString).m4a"
    }

    func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    func importFile(from sourceURL: URL) throws -> String {
        // fileImporter·공유 시트로 받은 파일은 보안 범위 접근이 필요하다.
        let isAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension.lowercased()
        let fileName = "\(UUID().uuidString).\(ext)"
        try fileManager.copyItem(at: sourceURL, to: url(for: fileName))
        return fileName
    }

    func duration(of fileName: String) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url(for: fileName))
        let duration = try await asset.load(.duration)
        let seconds = duration.seconds
        return seconds.isFinite ? seconds : 0
    }

    func remove(fileName: String) throws {
        let fileURL = url(for: fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }
}
