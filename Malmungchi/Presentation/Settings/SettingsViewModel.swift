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

    /// 키를 발급받는 페이지
    static let keyConsoleURL = URL(string: "https://console.anthropic.com/settings/keys")!

    private var trimmedInput: String {
        apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSaveKey: Bool {
        !trimmedInput.isEmpty
    }

    /// Anthropic API 키는 보통 `sk-ant-`로 시작한다. 다르면 안내만 하고 막지는 않는다.
    var showsKeyFormatHint: Bool {
        canSaveKey && !trimmedInput.hasPrefix("sk-ant-")
    }

    /// 입력한 키를 가려서 보여준다. 붙여넣은 키가 맞는지 확인하는 용도. 예: "sk-ant-…a1b2"
    var maskedKeyInput: String? {
        let key = trimmedInput
        guard !key.isEmpty else { return nil }
        guard key.count > 12 else { return String(repeating: "•", count: key.count) }
        return "\(key.prefix(7))…\(key.suffix(4))"
    }

    /// 붙여넣기 버튼으로 받은 글을 입력칸에 넣는다.
    func pasteKey(_ text: String) {
        apiKeyInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
