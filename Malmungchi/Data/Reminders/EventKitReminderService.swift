import EventKit
import Foundation

/// EventKit으로 기본 미리알림 목록에 항목을 추가한다.
final class EventKitReminderService: ReminderAdding {
    private let store: EKEventStore

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    var access: ReminderAccess {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToReminders()
    }

    func add(_ reminder: NewReminder) throws {
        guard let list = store.defaultCalendarForNewReminders() else { throw ReminderError.noDefaultList }
        let item = EKReminder(eventStore: store)
        item.title = reminder.title
        item.notes = reminder.notes
        item.calendar = list
        try store.save(item, commit: true)
    }
}
