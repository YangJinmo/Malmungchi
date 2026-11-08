import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section {
                Picker("모델", selection: $viewModel.transcriptionModel) {
                    ForEach(TranscriptionModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("받아쓰기 모델")
            } footer: {
                Text("\(viewModel.transcriptionModel.detail)\n바꾼 모델은 다음 받아쓰기부터 쓰고, 처음 쓸 때 내려받아요. 받아쓰기는 항상 기기 안에서 해요.")
            }

            Section {
                if viewModel.hasAPIKey {
                    Label("키가 저장되어 있어요", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }

                HStack(spacing: 12) {
                    SecureField(viewModel.hasAPIKey ? "새 키로 바꾸기" : "sk-ant-…", text: $viewModel.apiKeyInput)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PasteButton(payloadType: String.self) { strings in
                        if let text = strings.first {
                            Task { @MainActor in viewModel.pasteKey(text) }
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.capsule)
                }

                if let masked = viewModel.maskedKeyInput {
                    Text("입력한 키: \(masked)")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                }

                if viewModel.showsKeyFormatHint {
                    Label("보통 sk-ant- 로 시작해요. 맞는 키인지 확인해 주세요.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

            } header: {
                Text("하루 정리 (Claude)")
            }

            Section {
                Button {
                    viewModel.saveKey()
                } label: {
                    Text(viewModel.hasAPIKey ? "새 키로 바꾸기" : "키 저장")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canSaveKey)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if viewModel.hasAPIKey {
                    Button("저장된 키 지우기", role: .destructive) { viewModel.removeKey() }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            } footer: {
                Text("키는 이 기기의 키체인에만 저장해요. 정리할 때는 받아쓴 글만 Claude에 보내고, 오디오·파일 이름·녹음 제목은 보내지 않아요.")
            }

            Section {
                DisclosureGroup("API 키는 어디서 받나요?") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1. 아래 버튼으로 Anthropic 콘솔을 열고 로그인해요.")
                        Text("2. API Keys에서 Create Key를 눌러 키를 만들어요.")
                        Text("3. 키는 만든 직후에만 전체가 보여요. 바로 복사해 주세요.")
                        Text("4. 여기로 돌아와 오른쪽 붙여넣기 버튼을 누르고 저장해요.")
                        Text("키를 쓰려면 콘솔에서 크레딧을 충전해야 하고, 쓴 만큼 요금이 나가요. Claude 앱 구독(Pro·Max)과는 별개예요. 하루 정리 한 번은 보통 아주 적은 금액이에요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Link(destination: SettingsViewModel.keyConsoleURL) {
                            Label("키 발급 페이지 열기", systemImage: "arrow.up.right.square")
                        }
                        .padding(.top, 2)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
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
    }
}
