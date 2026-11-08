import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let settings: AppSettings
    private let apiKeys: APIKeyStoring

    var transcriptionModel: TranscriptionModel {
        didSet { settings.transcriptionModel = transcriptionModel }
    }

    /// 입력 중인 키. 저장하면 비운다. 저장된 키는 화면에 다시 보여주지 않는다.
    var apiKeyInput = ""
    private(set) var hasAPIKey = false
    var errorMessage: String?

    init(settings: AppSettings, apiKeys: APIKeyStoring) {
        self.settings = settings
        self.apiKeys = apiKeys
        self.transcriptionModel = settings.transcriptionModel
        refreshKeyState()
    }

    var canSaveKey: Bool {
        !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try apiKeys.save(key)
            apiKeyInput = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshKeyState()
    }

    func removeKey() {
        do {
            try apiKeys.delete()
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshKeyState()
    }

    private func refreshKeyState() {
        do {
            hasAPIKey = try apiKeys.load() != nil
        } catch {
            hasAPIKey = false
            errorMessage = error.localizedDescription
        }
    }
}
