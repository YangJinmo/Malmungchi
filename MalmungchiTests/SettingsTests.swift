import Foundation
import Testing
@testable import Malmungchi

@Suite("Settings")
struct SettingsTests {
    private func makeDefaults() -> UserDefaults {
        let name = "SettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("저장된 값이 없으면 기본 모델을 쓴다")
    func fallsBackToDefault() {
        let settings = UserDefaultsAppSettings(defaults: makeDefaults(), fallbackModel: .small)
        #expect(settings.transcriptionModel == .small)
    }

    @Test("고른 모델을 저장하고 다시 읽는다")
    func persistsSelection() {
        let defaults = makeDefaults()
        UserDefaultsAppSettings(defaults: defaults, fallbackModel: .base).transcriptionModel = .largeV3Turbo
        #expect(UserDefaultsAppSettings(defaults: defaults, fallbackModel: .base).transcriptionModel == .largeV3Turbo)
    }

    @Test("알 수 없는 저장값은 기본 모델로 돌아간다")
    func ignoresUnknownValue() {
        let defaults = makeDefaults()
        defaults.set("gigantic", forKey: "transcriptionModel")
        #expect(UserDefaultsAppSettings(defaults: defaults, fallbackModel: .base).transcriptionModel == .base)
    }

    @Test("모든 모델이 서로 다른 WhisperKit 이름에 대응한다")
    func whisperNamesAreDistinct() {
        let names = TranscriptionModel.allCases.map(WhisperKitTranscriber.whisperName(for:))
        #expect(Set(names).count == TranscriptionModel.allCases.count)
    }

    @MainActor
    @Test("SettingsViewModel은 모델을 바꾸면 설정에 저장한다")
    func viewModelWritesThrough() {
        let settings = InMemoryAppSettings(transcriptionModel: .base)
        let viewModel = SettingsViewModel(settings: settings, apiKeys: InMemoryAPIKeyStore())
        #expect(viewModel.transcriptionModel == .base)

        viewModel.transcriptionModel = .small
        #expect(settings.transcriptionModel == .small)
    }
}

@MainActor
@Suite("API key settings")
struct APIKeySettingsTests {
    private func makeViewModel(store: InMemoryAPIKeyStore = InMemoryAPIKeyStore()) -> SettingsViewModel {
        SettingsViewModel(settings: InMemoryAppSettings(), apiKeys: store)
    }

    @Test("저장된 키가 있으면 있다고만 알리고 값은 노출하지 않는다")
    func reflectsStoredKey() {
        #expect(makeViewModel(store: InMemoryAPIKeyStore(key: "sk-test")).hasAPIKey)
        #expect(!makeViewModel().hasAPIKey)
    }

    @Test("키를 저장하면 앞뒤 공백을 지우고 입력칸을 비운다")
    func saveTrimsAndClearsInput() {
        let store = InMemoryAPIKeyStore()
        let viewModel = makeViewModel(store: store)
        viewModel.apiKeyInput = "  sk-test \n"

        viewModel.saveKey()

        #expect(store.key == "sk-test")
        #expect(viewModel.apiKeyInput.isEmpty)
        #expect(viewModel.hasAPIKey)
    }

    @Test("빈 입력은 저장하지 않는다")
    func blankInputIsIgnored() {
        let store = InMemoryAPIKeyStore()
        let viewModel = makeViewModel(store: store)
        viewModel.apiKeyInput = "   "

        #expect(!viewModel.canSaveKey)
        viewModel.saveKey()
        #expect(store.key == nil)
    }

    @Test("붙여넣은 글은 앞뒤 공백을 지워 입력칸에 넣는다")
    func pasteTrims() {
        let viewModel = makeViewModel()
        viewModel.pasteKey("  sk-ant-api03-abcdef1234 \n")
        #expect(viewModel.apiKeyInput == "sk-ant-api03-abcdef1234")
    }

    @Test("입력한 키는 앞 7자와 뒤 4자만 보여준다")
    func masksInput() {
        let viewModel = makeViewModel()
        #expect(viewModel.maskedKeyInput == nil)

        viewModel.apiKeyInput = "sk-ant-api03-SECRETSECRET-a1b2"
        #expect(viewModel.maskedKeyInput == "sk-ant-…a1b2")

        viewModel.apiKeyInput = "short"
        #expect(viewModel.maskedKeyInput == "•••••")
    }

    @Test("sk-ant-로 시작하지 않으면 안내만 하고 저장은 막지 않는다")
    func formatHint() {
        let viewModel = makeViewModel()
        #expect(!viewModel.showsKeyFormatHint)

        viewModel.apiKeyInput = "sk-ant-api03-abcdef"
        #expect(!viewModel.showsKeyFormatHint)

        viewModel.apiKeyInput = "hello"
        #expect(viewModel.showsKeyFormatHint)
        #expect(viewModel.canSaveKey)
    }

    @Test("키를 지우면 없는 상태가 된다")
    func removeKey() {
        let store = InMemoryAPIKeyStore(key: "sk-test")
        let viewModel = makeViewModel(store: store)

        viewModel.removeKey()

        #expect(store.key == nil)
        #expect(!viewModel.hasAPIKey)
    }

    @Test("저장에 실패하면 에러를 보여주고 입력은 남겨 둔다")
    func saveFailureKeepsInput() {
        let store = InMemoryAPIKeyStore()
        store.failure = StubError()
        let viewModel = makeViewModel(store: store)
        store.failure = StubError()
        viewModel.apiKeyInput = "sk-test"

        viewModel.saveKey()

        #expect(viewModel.errorMessage == "stub failure")
        #expect(viewModel.apiKeyInput == "sk-test")
    }
}

/// 서명 없이 빌드하면(CI, CODE_SIGNING_ALLOWED=NO) 키체인 권한이 없어 -34018이 난다.
/// 그 환경에서는 건너뛰고, 서명된 빌드(Xcode에서 실행)에서 검증한다.
private let keychainIsAvailable: Bool = {
    do {
        _ = try KeychainAPIKeyStore(service: "com.yangjinmo.Malmungchi.tests.probe", account: "probe").load()
        return true
    } catch {
        return false
    }
}()

@Suite("KeychainAPIKeyStore", .enabled(if: keychainIsAvailable, "키체인 권한이 없는 서명 없는 빌드에서는 건너뛰어요"))
struct KeychainAPIKeyStoreTests {
    private func makeStore() -> KeychainAPIKeyStore {
        KeychainAPIKeyStore(service: "com.yangjinmo.Malmungchi.tests.\(UUID().uuidString)", account: "api-key")
    }

    @Test("저장, 읽기, 덮어쓰기, 삭제")
    func lifecycle() throws {
        let store = makeStore()
        defer { try? store.delete() }

        #expect(try store.load() == nil)

        try store.save("first")
        #expect(try store.load() == "first")

        try store.save("second")
        #expect(try store.load() == "second")

        try store.delete()
        #expect(try store.load() == nil)
    }

    @Test("없는 키를 지워도 에러가 아니다")
    func deleteMissingIsNoOp() throws {
        try makeStore().delete()
    }
}
