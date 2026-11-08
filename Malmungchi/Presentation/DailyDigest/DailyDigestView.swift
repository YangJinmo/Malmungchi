import SwiftUI

struct DailyDigestRoute: Hashable {
    let date: Date
}

struct DailyDigestView: View {
    @State private var viewModel: DailyDigestViewModel

    init(viewModel: DailyDigestViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            if let digest = viewModel.digest {
                Section("일기") {
                    Text(digest.diary)
                        .textSelection(.enabled)
                }

                Section("할 일") {
                    if digest.todos.isEmpty {
                        Text("없어요").foregroundStyle(.secondary)
                    }
                    ForEach(digest.todos) { todo in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(todo.text)
                            if let due = todo.due {
                                Text(due).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("결정 사항") {
                    if digest.decisions.isEmpty {
                        Text("없어요").foregroundStyle(.secondary)
                    }
                    ForEach(Array(digest.decisions.enumerated()), id: \.offset) { _, decision in
                        Text(decision.text)
                    }
                }

                Section {
                    Text("\(digest.generatedAt, format: .dateTime.month().day().hour().minute()) · \(digest.model)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if viewModel.digest == nil && !viewModel.isGenerating {
                ContentUnavailableView(
                    "아직 정리하지 않았어요",
                    systemImage: "text.book.closed",
                    description: Text("아래 버튼으로 이 날의 받아쓰기를 일기·할 일·결정 사항으로 정리해요.")
                )
            }
        }
        .navigationTitle(Text(viewModel.date, format: .dateTime.month().day().weekday(.wide)))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await viewModel.generate() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isGenerating { ProgressView().tint(.white) }
                    Text(viewModel.isGenerating ? "정리하는 중…" : (viewModel.digest == nil ? "하루 정리하기" : "다시 정리하기"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: Capsule())
            }
            .disabled(viewModel.isGenerating)
            .padding(.bottom, 8)
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
