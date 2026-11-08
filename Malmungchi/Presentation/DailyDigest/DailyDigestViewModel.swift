import Foundation
import Observation

@MainActor
@Observable
final class DailyDigestViewModel {
    let date: Date
    private(set) var digest: DailyDigest?
    private(set) var isGenerating = false
    var errorMessage: String?
    /// 미리알림에 넣으려고 사용자가 체크한 할 일
    private(set) var selectedTodoIDs: Set<UUID> = []
    private(set) var isAddingReminders = false
    /// 마지막으로 미리알림에 넣은 개수 안내
    var noticeMessage: String?
    /// 미리알림 권한이 꺼져 있어 설정 앱으로 안내해야 할 때 true
    private(set) var needsReminderSettings = false

    private let fetchDigest: FetchDailyDigestUseCase
    private let generateDigest: GenerateDailyDigestUseCase
    private let addTodos: AddTodosToRemindersUseCase

    init(
        date: Date,
        fetchDigest: FetchDailyDigestUseCase,
        generateDigest: GenerateDailyDigestUseCase,
        addTodos: AddTodosToRemindersUseCase
    ) {
        self.date = date
        self.fetchDigest = fetchDigest
        self.generateDigest = generateDigest
        self.addTodos = addTodos
    }

    func isReminded(_ todo: DigestTodo) -> Bool {
        digest?.remindedTodoIDs.contains(todo.id) ?? false
    }

    func isSelected(_ todo: DigestTodo) -> Bool {
        selectedTodoIDs.contains(todo.id)
    }

    func toggleSelection(_ todo: DigestTodo) {
        guard !isReminded(todo) else { return }
        if selectedTodoIDs.contains(todo.id) {
            selectedTodoIDs.remove(todo.id)
        } else {
            selectedTodoIDs.insert(todo.id)
        }
    }

    var canAddSelected: Bool { !selectedTodoIDs.isEmpty && !isAddingReminders }

    /// 체크한 할 일만 미리알림에 넣는다.
    func addSelectedToReminders() async {
        guard let digest, canAddSelected else { return }
        isAddingReminders = true
        needsReminderSettings = false
        defer { isAddingReminders = false }

        let before = digest.remindedTodoIDs
        do {
            let updated = try await addTodos.execute(todoIDs: selectedTodoIDs, in: digest)
            self.digest = updated
            let added = updated.remindedTodoIDs.subtracting(before).count
            selectedTodoIDs.subtract(updated.remindedTodoIDs)
            noticeMessage = "미리알림에 \(added)개를 넣었어요."
        } catch {
            if let latest = try? fetchDigest.execute(on: date) {
                self.digest = latest
                selectedTodoIDs.subtract(latest.remindedTodoIDs)
            }
            needsReminderSettings = (error as? ReminderError) == .accessDenied
            errorMessage = error.localizedDescription
        }
    }

    func load() {
        do {
            digest = try fetchDigest.execute(on: date)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 정리를 만든다. 실패하면 이전 정리는 그대로 두고 이유만 보여준다.
    func generate() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        do {
            digest = try await generateDigest.execute(on: date)
            selectedTodoIDs = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
