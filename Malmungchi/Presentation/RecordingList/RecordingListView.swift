import SwiftUI
import UniformTypeIdentifiers

struct RecordingListView: View {
    @State private var viewModel: RecordingListViewModel
    @State private var isImporting = false
    private let makeDetailViewModel: @MainActor (Recording) -> RecordingDetailViewModel
    private let makeDigestViewModel: @MainActor (Date) -> DailyDigestViewModel
    private let makeSettingsViewModel: @MainActor () -> SettingsViewModel

    init(
        viewModel: RecordingListViewModel,
        makeDetailViewModel: @escaping @MainActor (Recording) -> RecordingDetailViewModel,
        makeDigestViewModel: @escaping @MainActor (Date) -> DailyDigestViewModel,
        makeSettingsViewModel: @escaping @MainActor () -> SettingsViewModel
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeDetailViewModel = makeDetailViewModel
        self.makeDigestViewModel = makeDigestViewModel
        self.makeSettingsViewModel = makeSettingsViewModel
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.days) { day in
                    Section {
                        ForEach(day.recordings) { recording in
                            NavigationLink(value: recording) {
                                RecordingRow(
                                    recording: recording,
                                    isTranscribing: viewModel.transcribingIDs.contains(recording.id)
                                )
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.delete(recording.id)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        DayHeader(day: day)
                    }
                }
            }
            .overlay {
                if viewModel.days.isEmpty {
                    ContentUnavailableView(
                        "아직 기록이 없어요",
                        systemImage: "waveform",
                        description: Text("아래 버튼으로 녹음하거나, 통화 녹음·음성 메모를 가져오세요.")
                    )
                }
            }
            .navigationTitle("말뭉치")
            .navigationDestination(for: Recording.self) { recording in
                RecordingDetailView(viewModel: makeDetailViewModel(recording))
            }
            .navigationDestination(for: DailyDigestRoute.self) { route in
                DailyDigestView(viewModel: makeDigestViewModel(route.date))
            }
            .navigationDestination(for: SettingsRoute.self) { _ in
                SettingsView(viewModel: makeSettingsViewModel())
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: SettingsRoute()) {
                        Label("설정", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("가져오기", systemImage: "square.and.arrow.down")
                    }
                    .disabled(viewModel.isRecording)
                }
            }
            .safeAreaInset(edge: .bottom) {
                RecordButton(isRecording: viewModel.isRecording, elapsed: viewModel.elapsed) {
                    Task { await viewModel.toggleRecording() }
                }
                .padding(.bottom, 8)
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task {
                        for url in urls {
                            await viewModel.importAudio(from: url)
                        }
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .alert(
                "문제가 생겼어요",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear { viewModel.load() }
        }
    }
}

private struct SettingsRoute: Hashable {}

private struct DayHeader: View {
    let day: RecordingDay

    var body: some View {
        HStack {
            Text(day.date, format: .dateTime.month().day().weekday(.wide))
            Spacer()
            NavigationLink(value: DailyDigestRoute(date: day.date)) {
                Label("하루 정리", systemImage: "text.book.closed")
                    .font(.footnote)
                    .textCase(nil)
            }
            .padding(.trailing, 8)
            Text(DurationText.short(day.totalDuration))
                .monospacedDigit()
        }
    }
}

private struct RecordingRow: View {
    let recording: Recording
    let isTranscribing: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recording.source == .inApp ? "mic.fill" : "phone.fill")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title.isEmpty ? "녹음" : recording.title)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(recording.createdAt, format: .dateTime.hour().minute())
                    Text("·")
                    Text(DurationText.short(recording.duration))
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(status: recording.status, isTranscribing: isTranscribing)
        }
        .padding(.vertical, 2)
    }
}
