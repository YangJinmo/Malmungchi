import Foundation

/// 하루치 받아쓰기를 일기·할 일·결정 사항으로 정리한다. 구현체를 바꿔 다른 모델을 쓸 수 있다.
protocol DailyDigestGenerating {
    /// 결과에 기록할 모델 이름.
    var modelName: String { get }
    func generate(from input: DigestInput) async throws -> DigestContent
}

enum DigestGenerationError: Error, Equatable, LocalizedError {
    case missingAPIKey
    case unauthorized
    case rateLimited
    case inputTooLong
    /// 그 날 받아쓰기가 끝난 녹음이 없다.
    case nothingToDigest
    case network(String)
    case requestFailed(status: Int, message: String?)
    /// 모델 응답을 두 번 시도해도 읽지 못했다. `raw`는 마지막 응답 원문.
    case invalidResponse(reason: String, raw: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "설정에서 Claude API 키를 먼저 입력해 주세요."
        case .unauthorized: return "API 키가 올바르지 않아요. 설정에서 다시 확인해 주세요."
        case .rateLimited: return "요청이 너무 많아요. 잠시 뒤에 다시 시도해 주세요."
        case .inputTooLong: return "하루 분량이 너무 길어서 한 번에 정리할 수 없어요."
        case .nothingToDigest: return "이 날은 정리할 받아쓰기가 아직 없어요."
        case .network(let message): return "네트워크 문제가 있어요. \(message)"
        case .requestFailed(let status, let message):
            return "정리에 실패했어요. (\(status)) \(message ?? "")".trimmingCharacters(in: .whitespaces)
        case .invalidResponse(let reason, _): return "정리 결과를 읽지 못했어요. 다시 시도해 주세요. (\(reason))"
        }
    }
}
