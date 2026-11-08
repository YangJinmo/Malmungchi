import Foundation

/// 앱 설정. API 키처럼 비밀인 값은 여기에 두지 않는다 (`APIKeyStoring`).
protocol AppSettings: AnyObject {
    var transcriptionModel: TranscriptionModel { get set }
}
