import Foundation

/// 공유 시트 확장이 파일을 두고, 앱이 가져가는 앱 그룹 폴더(`Inbox`)의 규칙.
/// 앱과 확장이 같이 컴파일하므로 Foundation 밖의 것을 쓰지 않는다.
///
/// 구조: `Inbox/<uuid>/<원래 파일 이름>`. 폴더 하나가 공유 한 건이다.
enum SharedInbox {
    static let appGroupID = "group.com.yangjinmo.Malmungchi"
    static let folderName = "Inbox"
    static let fallbackFileName = "shared.m4a"

    /// 앱 그룹 Inbox 폴더. 서명 없는 빌드처럼 앱 그룹 권한이 없으면 nil.
    static func directoryURL(fileManager: FileManager = .default) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(folderName, isDirectory: true)
    }

    /// 파일 한 개를 `root` 아래 새 폴더로 복사한다. 실패하면 만든 폴더는 지운다.
    /// - Parameter originalName: 공유한 쪽이 알려 준 이름. 경로 문자는 걸러내고, 비면 기본 이름을 쓴다.
    @discardableResult
    static func stage(
        fileAt source: URL,
        originalName: String?,
        in root: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        let destination = folder.appendingPathComponent(safeFileName(originalName, source: source))
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            try? fileManager.removeItem(at: folder)
            throw error
        }
        return destination
    }

    static func safeFileName(_ name: String?, source: URL) -> String {
        let candidate = (name ?? source.lastPathComponent)
            .replacingOccurrences(of: "\\", with: "/")
        let last = (candidate as NSString).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !last.isEmpty, last != ".", last != ".." else { return fallbackFileName }
        return last
    }
}
