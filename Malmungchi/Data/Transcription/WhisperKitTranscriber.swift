import Foundation
import WhisperKit

/// WhisperKit으로 기기 안에서 받아쓴다. 오디오는 기기 밖으로 나가지 않는다.
///
/// 처음 쓰는 모델은 내려받는다 (large-v3 turbo 약 600MB, Wi-Fi 권장).
/// 모델은 설정에서 고르고, 받아쓸 때마다 현재 선택을 읽는다.
actor WhisperKitTranscriber: Transcribing {
    enum TranscriberError: Error, LocalizedError {
        case noResult

        var errorDescription: String? {
            switch self {
            case .noResult: return "받아쓴 내용이 없어요. 녹음에 말소리가 있는지 확인해 주세요."
            }
        }
    }

    /// 설정의 모델 → WhisperKit 모델 이름. large-v3 turbo는 iOS 권장 압축판.
    static func whisperName(for model: TranscriptionModel) -> String {
        switch model {
        case .base: return "openai_whisper-base"
        case .small: return "openai_whisper-small"
        case .largeV3Turbo: return "large-v3-v20240930_626MB"
        }
    }

    private let modelProvider: @Sendable () -> TranscriptionModel
    private var pipeline: WhisperKit?
    private var loadedModel: TranscriptionModel?

    init(modelProvider: @escaping @Sendable () -> TranscriptionModel) {
        self.modelProvider = modelProvider
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
        let model = modelProvider()
        if let pipeline, loadedModel == model { return pipeline }
        pipeline = nil
        loadedModel = nil
        let loaded = try await WhisperKit(WhisperKitConfig(model: Self.whisperName(for: model)))
        pipeline = loaded
        loadedModel = model
        return loaded
    }
}
