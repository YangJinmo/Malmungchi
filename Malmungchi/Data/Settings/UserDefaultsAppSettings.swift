import Foundation

final class UserDefaultsAppSettings: AppSettings {
    private enum Key {
        static let transcriptionModel = "transcriptionModel"
    }

    /// 개발 빌드는 빠른 모델, 배포 빌드는 정확한 모델이 기본이다.
    static var defaultTranscriptionModel: TranscriptionModel {
        #if DEBUG
        return .base
        #else
        return .largeV3Turbo
        #endif
    }

    private let defaults: UserDefaults
    private let fallbackModel: TranscriptionModel

    init(
        defaults: UserDefaults = .standard,
        fallbackModel: TranscriptionModel = UserDefaultsAppSettings.defaultTranscriptionModel
    ) {
        self.defaults = defaults
        self.fallbackModel = fallbackModel
    }

    var transcriptionModel: TranscriptionModel {
        get {
            defaults.string(forKey: Key.transcriptionModel)
                .flatMap(TranscriptionModel.init(rawValue:)) ?? fallbackModel
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.transcriptionModel)
        }
    }
}
