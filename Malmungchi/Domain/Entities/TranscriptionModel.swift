import Foundation

/// 받아쓰기 모델 크기. 클수록 정확하지만 느리고 메모리를 더 쓴다.
enum TranscriptionModel: String, CaseIterable, Codable, Sendable {
    case base
    case small
    case largeV3Turbo

    var displayName: String {
        switch self {
        case .base: return "빠름 (base)"
        case .small: return "보통 (small)"
        case .largeV3Turbo: return "정확 (large-v3 turbo)"
        }
    }

    var detail: String {
        switch self {
        case .base: return "약 150MB · 개발·테스트용으로 좋아요"
        case .small: return "약 500MB · 속도와 정확도의 중간"
        case .largeV3Turbo: return "약 600MB · 가장 정확하지만 오래 걸려요"
        }
    }
}
