import Foundation

/// 녹음 메타데이터 저장소.
protocol RecordingRepository: AnyObject {
    /// 최신순으로 정렬된 전체 녹음.
    func fetchAll() throws -> [Recording]
    func recording(id: UUID) throws -> Recording?
    /// 같은 id가 있으면 덮어쓴다.
    func save(_ recording: Recording) throws
    func delete(id: UUID) throws
}

/// 받아쓰기 결과 저장소.
protocol TranscriptRepository: AnyObject {
    func transcript(for recordingID: UUID) throws -> Transcript?
    /// 메타데이터(제목, 날짜)는 마크다운 내보내기에 쓰인다.
    func save(_ transcript: Transcript, for recording: Recording) throws
    func delete(for recordingID: UUID) throws
}

/// 오디오 파일 저장소.
protocol AudioStorage: AnyObject {
    func makeRecordingFileName() -> String
    func url(for fileName: String) -> URL
    /// 외부 파일을 복사해 오고 저장된 파일 이름을 돌려준다.
    func importFile(from sourceURL: URL) throws -> String
    func duration(of fileName: String) async throws -> TimeInterval
    func remove(fileName: String) throws
}
