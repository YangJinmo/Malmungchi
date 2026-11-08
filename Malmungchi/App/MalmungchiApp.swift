import SwiftUI

@main
struct MalmungchiApp: App {
    private let container: AppContainer?
    private let startupError: String?

    init() {
        do {
            container = try AppContainer.live()
            startupError = nil
        } catch {
            container = nil
            startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                RecordingListView(
                    viewModel: container.makeListViewModel(),
                    makeDetailViewModel: { container.makeDetailViewModel(for: $0) },
                    makeSettingsViewModel: { container.makeSettingsViewModel() }
                )
            } else {
                ContentUnavailableView(
                    "저장소를 열 수 없어요",
                    systemImage: "exclamationmark.triangle",
                    description: Text(startupError ?? "")
                )
            }
        }
    }
}
