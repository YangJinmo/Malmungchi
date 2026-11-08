import Foundation

enum ReminderAccess: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}

struct NewReminder: Equatable, Sendable {
    let title: String
    let notes: String?
}

enum ReminderError: Error, Equatable, LocalizedError {
    case accessDenied
    case noDefaultList

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "미리알림 접근이 꺼져 있어요. 설정 앱에서 말뭉치의 미리알림을 허용해 주세요."
        case .noDefaultList: return "미리알림의 기본 목록을 찾지 못했어요."
        }
    }
}

/// iOS 미리알림에 항목을 넣는다.
protocol ReminderAdding: AnyObject {
    var access: ReminderAccess { get }
    /// 권한을 요청한다. 허용되면 true.
    func requestAccess() async throws -> Bool
    func add(_ reminder: NewReminder) throws
}
