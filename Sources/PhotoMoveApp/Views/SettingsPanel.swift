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
                Toggle("Other Files", isOn: $viewModel.includeOtherFiles)
                    .help("Include non-media files (documents, archives, etc.)")
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

            // Row 3: Date fallback
            HStack(spacing: 12) {
                Text("No metadata:")
                    .fontWeight(.medium)

                Picker("", selection: $viewModel.dateFallback) {
                    ForEach(DateFallback.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .frame(width: 190)
                .labelsHidden()
                .help("What date to use when no EXIF/metadata date is found")

                Spacer()
            }

            // Row 4: Subfolders + Rename
            HStack(spacing: 12) {
                Toggle("Videos subfolder", isOn: $viewModel.separateVideos)
                    .help("Place videos inside a 'Videos' subfolder (e.g. 2026/01/26/Videos)")

                Divider().frame(height: 16)

                Toggle("Camera subfolder", isOn: $viewModel.separateByCamera)
                    .help("Create a subfolder with the camera model name (when available)")

                Divider().frame(height: 16)

                Toggle("Rename with date", isOn: $viewModel.renameWithDate)
                    .help("Prepend date to filename: 20260312_143522123_originalname.jpg")

                Spacer()
            }

            // Row 5: Integrity verification
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
