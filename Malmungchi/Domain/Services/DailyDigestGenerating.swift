import Foundation

/// 하루치 받아쓰기를 일기·할 일·결정 사항으로 정리한다. 구현체를 바꿔 다른 모델을 쓸 수 있다.
protocol DailyDigestGenerating {
    /// 결과에 기록할 모델 이름.
    var modelName: String { get }
    func generate(from input: DigestInput) async throws -> DigestContent
}
