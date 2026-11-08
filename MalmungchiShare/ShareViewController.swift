import UIKit
import UniformTypeIdentifiers

/// 공유 시트에서 "말뭉치"를 고르면 오디오 파일을 앱 그룹 Inbox에 복사하고 닫는다.
/// 가져오기와 받아쓰기는 앱이 열릴 때 한다 (확장은 메모리 제한이 작다).
final class ShareViewController: UIViewController {
    private let label = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        label.text = "말뭉치에 담는 중이에요…"
        label.font = .preferredFont(forTextStyle: .body)
        label.textAlignment = .center
        label.numberOfLines = 0
        spinner.startAnimating()

        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])

        Task { @MainActor in await stageSharedAudio() }
    }

    @MainActor
    private func stageSharedAudio() async {
        guard let root = SharedInbox.directoryURL() else {
            finish(message: "말뭉치를 열 수 없어요. 앱을 한 번 실행한 뒤 다시 시도해 주세요.", failed: true)
            return
        }

        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.audio.identifier) }

        var staged = 0
        var firstError: Error?
        for provider in providers {
            do {
                try await stage(provider, in: root)
                staged += 1
            } catch {
                firstError = firstError ?? error
            }
        }

        switch (staged, providers.count) {
        case (0, 0):
            finish(message: "오디오 파일이 아니에요.", failed: true)
        case (0, _):
            finish(message: "담지 못했어요. \(firstError?.localizedDescription ?? "")", failed: true)
        case (let done, let total) where done < total:
            finish(message: "\(total)개 중 \(done)개만 담았어요.\n앱을 열면 가져와요.", failed: false)
        default:
            finish(message: "말뭉치에 \(staged)개를 담았어요.\n앱을 열면 가져와요.", failed: false)
        }
    }

    private func stage(_ provider: NSItemProvider, in root: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // 임시 파일은 이 콜백이 끝나면 사라지므로 안에서 복사한다.
            provider.loadFileRepresentation(forTypeIdentifier: UTType.audio.identifier) { url, error in
                guard let url else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                    return
                }
                do {
                    try SharedInbox.stage(fileAt: url, originalName: nil, in: root)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @MainActor
    private func finish(message: String, failed: Bool) {
        spinner.stopAnimating()
        label.text = message
        DispatchQueue.main.asyncAfter(deadline: .now() + (failed ? 2.0 : 1.2)) { [weak self] in
            if failed {
                self?.extensionContext?.cancelRequest(withError: CocoaError(.fileWriteUnknown))
            } else {
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }
}
