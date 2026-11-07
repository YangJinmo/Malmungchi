import Foundation

/// 녹음이 어디서 들어왔는지.
enum RecordingSource: String, Codable, Hashable, Sendable {
    /// 앱 안에서 직접 녹음
    case inApp
    /// 통화 녹음·음성 메모 등 외부 파일을 가져옴
    case imported
}

/// 받아쓰기 진행 상태.
enum TranscriptionStatus: Codable, Hashable, Sendable {
    case pending
    case inProgress
    case completed
    case failed(message: String)
}

/// 하나의 오디오 기록. 오디오 파일 자체는 `AudioStorage`가, 메타데이터는 `RecordingRepository`가 관리한다.
struct Recording: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let fileName: String
    var title: String
    let duration: TimeInterval
    let source: RecordingSource
    var status: TranscriptionStatus

    init(
        id: UUID = UUID(),
        createdAt: Date,
        fileName: String,
        title: String,
        duration: TimeInterval,
        source: RecordingSource,
        status: TranscriptionStatus = .pending
    ) {
        self.id = id
        self.createdAt = createdAt
        self.fileName = fileName
        self.title = title
        self.duration = duration
        self.source = source
        self.status = status
    }
}
