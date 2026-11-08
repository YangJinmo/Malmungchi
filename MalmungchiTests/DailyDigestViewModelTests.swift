import Foundation
import Testing
@testable import Malmungchi

@MainActor
@Suite("DailyDigestViewModel")
struct DailyDigestViewModelTests {
    private let day = Fixtures.date(2026, 11, 4)

    private struct SUT {
        let viewModel: DailyDigestViewModel
        let digests: InMemoryDigestRepository
        let generator: FakeDigestGenerator
        let reminders: FakeReminderService
    }

    private func makeSUT(generator: FakeDigestGenerator = FakeDigestGenerator(), withTranscript: Bool = true) throws -> SUT {
        let recording = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 9), status: .completed)
        let recordings = InMemoryRecordingRepository([recording])
        let transcripts = InMemoryTranscriptRepository()
        if withTranscript {
            try transcripts.save(
                Transcript(recordingID: recording.id, language: "ko", segments: [TranscriptSegment(start: 0, end: 2, text: "안녕")], createdAt: recording.createdAt),
                for: recording
            )
        }
        let digests = InMemoryDigestRepository()
        let reminders = FakeReminderService()
        let viewModel = DailyDigestViewModel(
            date: day,
            fetchDigest: FetchDailyDigestUseCase(digests: digests, calendar: Fixtures.seoulCalendar),
            generateDigest: GenerateDailyDigestUseCase(
                recordings: recordings, transcripts: transcripts, digests: digests,
                generator: generator, calendar: Fixtures.seoulCalendar,
                now: { Fixtures.date(2026, 11, 4, 23) }
            ),
            addTodos: AddTodosToRemindersUseCase(reminders: reminders, digests: digests, dayFormatter: MarkdownDigestFormatter(timeZone: Fixtures.seoul))
        )
        return SUT(viewModel: viewModel, digests: digests, generator: generator, reminders: reminders)
    }

    @Test("저장된 정리가 있으면 load로 보여준다")
    func loadShowsExistingDigest() throws {
        let sut = try makeSUT()
        let digest = DailyDigest(date: day, diary: "저장된 일기", todos: [], decisions: [], generatedAt: day, model: "m")
        try sut.digests.save(digest)

        sut.viewModel.load()

        #expect(sut.viewModel.digest == digest)
    }

    @Test("정리를 만들면 결과를 보여주고 진행 표시를 끈다")
    func generateShowsResult() async throws {
        let sut = try makeSUT()

        await sut.viewModel.generate()

        #expect(sut.viewModel.digest?.diary == Fixtures.sampleContent.diary)
        #expect(!sut.viewModel.isGenerating)
        #expect(sut.viewModel.errorMessage == nil)
    }

    @Test("실패하면 이유를 보여주고 이전 정리는 남긴다")
    func failureKeepsPreviousDigest() async throws {
        let sut = try makeSUT()
        await sut.viewModel.generate()
        let previous = sut.viewModel.digest

        sut.generator.result = .failure(DigestGenerationError.missingAPIKey)
        await sut.viewModel.generate()

        #expect(sut.viewModel.digest == previous)
        #expect(sut.viewModel.errorMessage == DigestGenerationError.missingAPIKey.errorDescription)
        #expect(!sut.viewModel.isGenerating)
    }

    @Test("받아쓰기가 없는 날은 안내 문구를 보여준다")
    func nothingToDigestMessage() async throws {
        let sut = try makeSUT(withTranscript: false)

        await sut.viewModel.generate()

        #expect(sut.viewModel.digest == nil)
        #expect(sut.viewModel.errorMessage == DigestGenerationError.nothingToDigest.errorDescription)
        #expect(sut.generator.inputs.isEmpty)
    }

    // MARK: - Reminders

    private func makeSUTWithTodos() async throws -> (SUT, [DigestTodo]) {
        let content = DigestContent(
            diary: "일기",
            todos: [DigestTodo(text: "견적서 보내기", due: "금요일"), DigestTodo(text: "우유 사기")],
            decisions: []
        )
        let sut = try makeSUT(generator: FakeDigestGenerator(result: .success(content)))
        await sut.viewModel.generate()
        return (sut, try #require(sut.viewModel.digest).todos)
    }

    @Test("고르지 않으면 아무것도 미리알림에 넣지 않는다")
    func nothingSelectedAddsNothing() async throws {
        let (sut, _) = try await makeSUTWithTodos()

        #expect(!sut.viewModel.canAddSelected)
        await sut.viewModel.addSelectedToReminders()

        #expect(sut.reminders.added.isEmpty)
    }

    @Test("고른 할 일만 미리알림에 넣고, 기한과 출처를 메모에 적는다")
    func addsOnlySelected() async throws {
        let (sut, todos) = try await makeSUTWithTodos()

        sut.viewModel.toggleSelection(todos[0])
        await sut.viewModel.addSelectedToReminders()

        #expect(sut.reminders.added.map(\.title) == ["견적서 보내기"])
        #expect(sut.reminders.added[0].notes == "기한: 금요일\n말뭉치 2026-11-04 하루 정리")
        #expect(sut.viewModel.isReminded(todos[0]))
        #expect(!sut.viewModel.isReminded(todos[1]))
        #expect(sut.viewModel.noticeMessage == "미리알림에 1개를 넣었어요.")
        #expect(sut.viewModel.selectedTodoIDs.isEmpty)
    }

    @Test("이미 넣은 할 일은 다시 고를 수 없고 두 번 넣지 않는다")
    func noDuplicates() async throws {
        let (sut, todos) = try await makeSUTWithTodos()
        sut.viewModel.toggleSelection(todos[0])
        await sut.viewModel.addSelectedToReminders()

        sut.viewModel.toggleSelection(todos[0])
        #expect(!sut.viewModel.isSelected(todos[0]))
        await sut.viewModel.addSelectedToReminders()

        #expect(sut.reminders.added.count == 1)
    }

    @Test("권한을 처음 물을 때 허용하면 넣는다")
    func requestsAccessFirst() async throws {
        let (sut, todos) = try await makeSUTWithTodos()
        sut.reminders.access = .notDetermined
        sut.reminders.grantOnRequest = true

        sut.viewModel.toggleSelection(todos[1])
        await sut.viewModel.addSelectedToReminders()

        #expect(sut.reminders.requestCount == 1)
        #expect(sut.reminders.added.map(\.title) == ["우유 사기"])
    }

    @Test("권한이 꺼져 있으면 넣지 않고 설정으로 안내한다")
    func deniedAccess() async throws {
        let (sut, todos) = try await makeSUTWithTodos()
        sut.reminders.access = .denied

        sut.viewModel.toggleSelection(todos[0])
        await sut.viewModel.addSelectedToReminders()

        #expect(sut.reminders.added.isEmpty)
        #expect(sut.viewModel.needsReminderSettings)
        #expect(sut.viewModel.errorMessage == ReminderError.accessDenied.errorDescription)
        #expect(sut.viewModel.isSelected(todos[0]))
    }

    @Test("권한 요청을 거절하면 넣지 않는다")
    func requestRefused() async throws {
        let (sut, todos) = try await makeSUTWithTodos()
        sut.reminders.access = .notDetermined
        sut.reminders.grantOnRequest = false

        sut.viewModel.toggleSelection(todos[0])
        await sut.viewModel.addSelectedToReminders()

        #expect(sut.reminders.added.isEmpty)
        #expect(sut.viewModel.needsReminderSettings)
    }

    @Test("중간에 실패하면 그때까지 넣은 것은 기록하고 나머지는 선택된 채로 둔다")
    func partialFailureKeepsProgress() async throws {
        let (sut, todos) = try await makeSUTWithTodos()
        sut.reminders.failOnAddNumber = 2
        sut.viewModel.toggleSelection(todos[0])
        sut.viewModel.toggleSelection(todos[1])

        await sut.viewModel.addSelectedToReminders()

        #expect(sut.reminders.added.count == 1)
        #expect(sut.viewModel.digest?.remindedTodoIDs.count == 1)
        #expect(sut.digests.items.values.first?.remindedTodoIDs.count == 1)
        #expect(sut.viewModel.errorMessage == "stub failure")
        #expect(sut.viewModel.selectedTodoIDs.count == 1)
    }

    @Test("정리를 다시 만들면 선택은 초기화된다")
    func regenerateClearsSelection() async throws {
        let (sut, todos) = try await makeSUTWithTodos()
        sut.viewModel.toggleSelection(todos[0])

        await sut.viewModel.generate()

        #expect(sut.viewModel.selectedTodoIDs.isEmpty)
    }
}
