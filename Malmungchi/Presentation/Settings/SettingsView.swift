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
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
    }
}
