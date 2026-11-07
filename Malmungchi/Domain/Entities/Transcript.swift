import Foundation

/// 받아쓰기 결과의 한 구간. 시간은 녹음 시작 기준 초 단위.
struct TranscriptSegment: Codable, Hashable, Sendable {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

/// 받아쓰기 엔진이 돌려주는 결과. 어떤 녹음인지는 모른다.
struct TranscriptionOutput: Equatable, Sendable {
    let language: String
    let segments: [TranscriptSegment]
}

/// 저장되는 받아쓰기 결과.
struct Transcript: Codable, Hashable, Sendable {
    let recordingID: UUID
    let language: String
    let segments: [TranscriptSegment]
    let createdAt: Date

    /// 구간을 이어 붙인 전체 텍스트.
    var text: String {
        segments
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

extension Transcript {
    /// 재생 위치에 해당하는 구간의 인덱스. 시작 시각이 `time` 이하인 마지막 구간을 고른다.
    /// 첫 구간보다 앞이거나 구간이 없으면 nil.
    func segmentIndex(at time: TimeInterval) -> Int? {
        segments.lastIndex { $0.start <= time }
    }
}

enum DomainError: Error, Equatable, LocalizedError {
    case recordingNotFound
    case notRecording
    case alreadyRecording

    var errorDescription: String? {
        switch self {
        case .recordingNotFound: return "녹음을 찾을 수 없어요."
        case .notRecording: return "진행 중인 녹음이 없어요."
        case .alreadyRecording: return "이미 녹음 중이에요."
        }
    }
}
