import Foundation
import WhisperKit

/// WhisperKit으로 기기 안에서 받아쓴다. 오디오는 기기 밖으로 나가지 않는다.
///
/// 처음 실행할 때 모델을 내려받는다 (기본 모델 약 600MB, Wi-Fi 권장).
/// 개발 중에는 `modelName: "base"`처럼 작은 모델로 바꾸면 빠르다.
actor WhisperKitTranscriber: Transcribing {
    enum TranscriberError: Error, LocalizedError {
        case noResult

        var errorDescription: String? {
            switch self {
            case .noResult: return "받아쓴 내용이 없어요. 녹음에 말소리가 있는지 확인해 주세요."
            }
        }
    }

    /// iOS 권장 다국어 모델 (Large v3 Turbo 압축판)
    static let defaultModel = "large-v3-v20240930_626MB"

    private let modelName: String
    private var pipeline: WhisperKit?

    init(modelName: String = WhisperKitTranscriber.defaultModel) {
        self.modelName = modelName
    }

    func transcribe(audioURL: URL, language: String) async throws -> TranscriptionOutput {
        let pipeline = try await loadPipeline()
        let options = DecodingOptions(
            language: language,
            skipSpecialTokens: true,
            chunkingStrategy: .vad
        )

        let results = await pipeline.transcribe(audioPaths: [audioURL.path], decodeOptions: options)
        guard let fileResults = results.first ?? nil, !fileResults.isEmpty else {
            throw TranscriberError.noResult
        }

        let segments = fileResults
            .flatMap(\.segments)
            .map { segment in
                TranscriptSegment(
                    start: TimeInterval(segment.start),
                    end: TimeInterval(segment.end),
                    text: segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.text.isEmpty }
            .sorted { $0.start < $1.start }

        guard !segments.isEmpty else { throw TranscriberError.noResult }
        return TranscriptionOutput(language: fileResults.first?.language ?? language, segments: segments)
    }

    private func loadPipeline() async throws -> WhisperKit {
        if let pipeline { return pipeline }
        let loaded = try await WhisperKit(WhisperKitConfig(model: modelName))
        pipeline = loaded
        return loaded
    }
}
