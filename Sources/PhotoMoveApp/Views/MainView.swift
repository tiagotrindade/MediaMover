import SwiftUI

struct MainView: View {
    @State private var viewModel = OrganizerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("PhotoMove")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 12)
                .padding(.bottom, 4)

            // Folder selection
            FolderPickerSection(viewModel: viewModel)

            Divider()

            // Pattern + settings
            PatternPickerView(viewModel: viewModel)
            SettingsPanel(viewModel: viewModel)

            Divider()

            // Content area
            Group {
                if viewModel.isScanning {
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(viewModel.scanMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isProcessing {
                    ProgressPanel(viewModel: viewModel)
                        .frame(maxWidth: .infinity)
                } else if let result = viewModel.result {
                    ResultsView(result: result, onDismiss: { viewModel.reset() })
                        .frame(maxWidth: .infinity)
                } else if !viewModel.discoveredFiles.isEmpty {
                    fileList
                } else {
                    Text("Select a source folder and click Scan to find media files.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minHeight: 120)

            Divider()

            // Bottom bar
            HStack {
                Button("Scan") {
                    Task { await viewModel.scanFiles() }
                }
                .disabled(viewModel.sourceURL == nil || viewModel.isScanning || viewModel.isProcessing)

                Spacer()

                if !viewModel.discoveredFiles.isEmpty {
                    let photoCount = viewModel.discoveredFiles.filter { $0.mediaType == .photo }.count
                    let videoCount = viewModel.discoveredFiles.filter { $0.mediaType == .video }.count
                    Text("\(viewModel.discoveredFiles.count) files (\(photoCount) photos, \(videoCount) videos)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Organize") {
                    Task { await viewModel.startOrganizing() }
                }
                .disabled(
                    viewModel.discoveredFiles.isEmpty ||
                    viewModel.destinationURL == nil ||
                    viewModel.isProcessing ||
                    viewModel.isScanning
                )
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 450)
    }

    private var fileList: some View {
        List(viewModel.discoveredFiles) { file in
            HStack {
                Image(systemName: file.mediaType == .photo ? "photo" : "video")
                    .foregroundStyle(file.mediaType == .photo ? .blue : .purple)
                    .frame(width: 20)

                VStack(alignment: .leading) {
                    Text(file.fileName)
                        .lineLimit(1)
                    Text(file.dateTaken != nil ? "EXIF: \(formatted(file.dateTaken!))" : "File date: \(formatted(file.fileModificationDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let cam = file.cameraModel {
                    Text(cam)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(formattedSize(file.fileSize))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
