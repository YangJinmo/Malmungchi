import Foundation
import Observation

@MainActor
@Observable
final class DailyDigestViewModel {
    let date: Date
    private(set) var digest: DailyDigest?
    private(set) var isGenerating = false
    var errorMessage: String?

    private let fetchDigest: FetchDailyDigestUseCase
    private let generateDigest: GenerateDailyDigestUseCase

    init(date: Date, fetchDigest: FetchDailyDigestUseCase, generateDigest: GenerateDailyDigestUseCase) {
        self.date = date
        self.fetchDigest = fetchDigest
        self.generateDigest = generateDigest
    }

    func load() {
        do {
            digest = try fetchDigest.execute(on: date)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 정리를 만든다. 실패하면 이전 정리는 그대로 두고 이유만 보여준다.
    func generate() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        do {
            digest = try await generateDigest.execute(on: date)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
