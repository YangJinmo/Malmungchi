import Foundation

/// `SharedInbox` 규칙(`<root>/<uuid>/<파일>`)대로 쌓인 공유 파일을 읽는다.
final class FileSharedAudioInbox: SharedAudioInbox {
    private let root: URL
    private let fileManager: FileManager

    init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    func pendingFiles() throws -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }

        let folders = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        return try folders
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { modified($0) < modified($1) }
            .compactMap { folder in
                try fileManager
                    .contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                    .first
            }
    }

    func remove(_ file: URL) throws {
        // 파일이 든 공유 폴더째 지운다. 폴더가 root 밑이 아니면 파일만 지운다.
        let folder = file.deletingLastPathComponent()
        let target = folder.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL ? folder : file
        guard fileManager.fileExists(atPath: target.path) else { return }
        try fileManager.removeItem(at: target)
    }

    private func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
