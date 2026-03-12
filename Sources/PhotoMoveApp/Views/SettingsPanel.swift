import SwiftUI

struct SettingsPanel: View {
    @Bindable var viewModel: OrganizerViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                // Operation mode
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

                // Duplicate handling
                HStack {
                    Text("Duplicates:")
                        .fontWeight(.medium)
                    Picker("", selection: $viewModel.duplicateHandling) {
                        ForEach(DuplicateHandling.allCases, id: \.self) { handling in
                            Text(handling.rawValue).tag(handling)
                        }
                    }
                    .frame(width: 120)
                    .labelsHidden()
                }
            }

            HStack(spacing: 20) {
                Toggle("Photos", isOn: $viewModel.includePhotos)
                Toggle("Videos", isOn: $viewModel.includeVideos)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
