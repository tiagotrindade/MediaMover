import SwiftUI

struct MainView: View {
    @State private var viewModel = OrganizerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("MediaMover")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                HStack(spacing: 8) {
                    // Undo button
                    Button {
                        Task { await viewModel.performUndo() }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!viewModel.canUndo || viewModel.isUndoing || viewModel.isProcessing)
                    .help("Undo last operation")

                    // Activity Log button
                    Button {
                        viewModel.showLogSheet = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .help("View activity log")
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 12)
            .padding(.bottom, 4)

            // Undo message
            if let undoMsg = viewModel.undoMessage {
                Text(undoMsg)
                    .font(.caption)
                    .foregroundStyle(.cyan)
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }

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
                } else if viewModel.isUndoing {
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Undoing last operation...")
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
        .frame(minWidth: 700, minHeight: 550)
        .task {
            await viewModel.refreshUndoState()
        }
        // Activity Log sheet
        .sheet(isPresented: $viewModel.showLogSheet) {
            VStack {
                ActivityLogView(viewModel: viewModel)
                HStack {
                    Spacer()
                    Button("Close") { viewModel.showLogSheet = false }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .frame(minWidth: 700, minHeight: 500)
        }
        // Duplicate resolution dialog
        .sheet(isPresented: $viewModel.showDuplicateDialog) {
            DuplicateResolverSheet(viewModel: viewModel)
        }
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

// MARK: - Duplicate Resolver Sheet

struct DuplicateResolverSheet: View {
    @Bindable var viewModel: OrganizerViewModel

    var body: some View {
        VStack(spacing: 16) {
            Label("Duplicate File Found", systemImage: "doc.on.doc.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Source file:")
                        .fontWeight(.medium)
                    VStack(alignment: .leading) {
                        Text(viewModel.duplicateSourceName)
                            .lineLimit(1)
                        Text(formattedSize(viewModel.duplicateSourceSize))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                GridRow {
                    Text("Existing file:")
                        .fontWeight(.medium)
                    VStack(alignment: .leading) {
                        Text(viewModel.duplicateExistingName)
                            .lineLimit(1)
                        Text(formattedSize(viewModel.duplicateExistingSize))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.callout)

            Divider()

            Toggle("Apply to all remaining duplicates", isOn: $viewModel.applyDuplicateToAll)
                .font(.callout)

            HStack(spacing: 12) {
                Button("Skip") {
                    viewModel.resolveDuplicate(action: nil)
                }

                Spacer()

                Button("Rename") {
                    viewModel.resolveDuplicate(action: .rename)
                }

                Button("Replace") {
                    viewModel.resolveDuplicate(action: .overwrite)
                }

                Button("Replace if Larger") {
                    viewModel.resolveDuplicate(action: .overwriteIfLarger)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
