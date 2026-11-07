import SwiftUI

struct RecordingDetailView: View {
    @State private var viewModel: RecordingDetailViewModel

    init(viewModel: RecordingDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollViewReader { proxy in
        List {
            Section {
                PlayerControls(
                    isPlaying: viewModel.isPlaying,
                    time: viewModel.playbackTime,
                    duration: viewModel.playbackDuration,
                    onToggle: { viewModel.togglePlayback() },
                    onSeek: { viewModel.seek(to: $0) },
                    onSkip: { viewModel.skip(by: $0) }
                )
            }

            Section {
                LabeledContent("날짜") {
                    Text(viewModel.recording.createdAt, format: .dateTime.year().month().day().hour().minute())
                }
                LabeledContent("길이", value: DurationText.short(viewModel.recording.duration))
                LabeledContent("출처", value: viewModel.recording.source == .inApp ? "앱에서 녹음" : "가져온 파일")
            }

            if let transcript = viewModel.transcript {
                Section {
                    ForEach(Array(transcript.segments.enumerated()), id: \.offset) { index, segment in
                        let isCurrent = index == viewModel.currentSegmentIndex
                        Button {
                            viewModel.play(from: segment)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(MarkdownTranscriptFormatter.timestamp(segment.start))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                                Text(segment.text)
                                    .fontWeight(isCurrent ? .semibold : .regular)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            isCurrent ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground)
                        )
                        .id(index)
                    }
                } header: {
                    Text("받아쓰기")
                } footer: {
                    Text("문장을 누르면 그 부분부터 재생돼요.")
                }
            } else {
                Section {
                    transcribeButton
                } footer: {
                    if case .failed(let message) = viewModel.recording.status {
                        Text("지난 시도 실패: \(message)")
                    } else {
                        Text("받아쓰기는 기기 안에서 처리돼요. 처음 한 번은 모델을 내려받아요.")
                    }
                }
            }
        }
        .onChange(of: viewModel.currentSegmentIndex) { _, index in
            guard viewModel.isPlaying, let index else { return }
            withAnimation { proxy.scrollTo(index, anchor: .center) }
        }
        }
        .navigationTitle(viewModel.recording.title.isEmpty ? "녹음" : viewModel.recording.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let markdown = viewModel.markdown {
                    ShareLink(item: markdown) {
                        Label("공유", systemImage: "square.and.arrow.up")
                    }
                }
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
        .onDisappear { viewModel.stopPlayback() }
    }

    @ViewBuilder
    private var transcribeButton: some View {
        if viewModel.isTranscribing || viewModel.recording.status == .inProgress {
            HStack {
                ProgressView()
                Text("받아쓰는 중…")
                    .foregroundStyle(.secondary)
            }
        } else {
            Button {
                Task { await viewModel.transcribe() }
            } label: {
                Label("받아쓰기", systemImage: "text.bubble")
            }
        }
    }
}
