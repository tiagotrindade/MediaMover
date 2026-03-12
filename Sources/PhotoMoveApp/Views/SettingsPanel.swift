import SwiftUI

struct SettingsPanel: View {
    @Bindable var viewModel: OrganizerViewModel

    var body: some View {
        VStack(spacing: 10) {
            // Row 1: Mode + Media Types
            HStack(spacing: 20) {
                HStack {
                    Text("Mode:")
                        .fontWeight(.medium)
                    Picker("", selection: $viewModel.operationMode) {
                        ForEach(OperationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                    .labelsHidden()
                }

                Toggle("Photos", isOn: $viewModel.includePhotos)
                Toggle("Videos", isOn: $viewModel.includeVideos)
            }

            // Row 2: Duplicate handling
            HStack(spacing: 12) {
                Text("Duplicates:")
                    .fontWeight(.medium)

                Picker("", selection: $viewModel.duplicateStrategy) {
                    ForEach(DuplicateStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.rawValue).tag(strategy)
                    }
                }
                .frame(width: 150)
                .labelsHidden()

                if viewModel.duplicateStrategy == .automatic {
                    Picker("Action:", selection: $viewModel.duplicateAction) {
                        ForEach(DuplicateAction.allCases, id: \.self) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .frame(width: 160)
                    .labelsHidden()
                }
            }

            // Row 3: Integrity verification
            HStack(spacing: 12) {
                Toggle("Verify integrity after copy", isOn: $viewModel.verifyIntegrity)

                if viewModel.verifyIntegrity {
                    Picker("", selection: $viewModel.hashAlgorithm) {
                        ForEach(HashAlgorithm.allCases, id: \.self) { algo in
                            Text(algo.rawValue).tag(algo)
                        }
                    }
                    .frame(width: 170)
                    .labelsHidden()
                }

                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
