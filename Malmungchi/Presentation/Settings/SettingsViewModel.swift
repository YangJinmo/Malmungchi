import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let settings: AppSettings

    var transcriptionModel: TranscriptionModel {
        didSet { settings.transcriptionModel = transcriptionModel }
    }

    init(settings: AppSettings) {
        self.settings = settings
        self.transcriptionModel = settings.transcriptionModel
    }
}
