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
        let viewModel = SettingsViewModel(settings: settings)
        #expect(viewModel.transcriptionModel == .base)

        viewModel.transcriptionModel = .small
        #expect(settings.transcriptionModel == .small)
    }
}
