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
                    Label("키가 저장되어 있어요", systemImage: "checkmark.seal")
                        .foregroundStyle(.green)
                    Button("키 지우기", role: .destructive) { viewModel.removeKey() }
                }
                SecureField(viewModel.hasAPIKey ? "새 키로 바꾸기" : "Claude API 키", text: $viewModel.apiKeyInput)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("저장") { viewModel.saveKey() }
                    .disabled(!viewModel.canSaveKey)
            } header: {
                Text("하루 정리 (Claude)")
            } footer: {
                Text("키는 이 기기의 키체인에만 저장해요. 정리할 때는 받아쓴 글만 Claude에 보내고, 오디오·파일 이름·녹음 제목은 보내지 않아요.")
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
