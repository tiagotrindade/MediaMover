import SwiftUI

struct RenameView: View {
    @State private var viewModel = RenameViewModel()
    @State private var previews: [RenameViewModel.RenamePreview] = []

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Mass Rename")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button("Reset") {
                        viewModel.reset()
                        previews = []
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Divider()

                ScrollView {
                    VStack(spacing: 16) {
                        // Folder cards
                        folderSection
                        // Pattern picker
                        patternSection
                        // File types + options
                        optionsRow
                        // Preview list
                        if !previews.isEmpty {
                            previewList
                        }
                        // Complete message
                        if viewModel.renameComplete {
                            completeMessage
                        }
                    }
                    .padding(20)
                }

                Divider()

                // Bottom bar
                bottomBar
            }
        }
        .frame(minWidth: 680, minHeight: 500)
        // Progress overlay
        .overlay(alignment: .center) {
            if viewModel.isScanning || viewModel.isRenaming {
                progressOverlay
            }
        }
        .onChange(of: viewModel.pattern) {
            // Re-scan needed to regenerate sequence numbers correctly
            if !previews.isEmpty {
                Task { previews = await viewModel.scanAndPreview() }
            }
        }
    }

    // MARK: - Folder Section

    private var folderSection: some View {
        VStack(spacing: 12) {
            // Source folder
            HStack(spacing: 12) {
                FolderCard(
                    label: "Source",
                    icon: "folder",
                    url: viewModel.sourceURL,
                    color: .orange
                ) {
                    viewModel.selectSource()
                }

                // Subfolders toggle
                VStack(spacing: 4) {
                    Toggle(isOn: $viewModel.includeSubfolders) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 10))
                            Text("Subfolders")
                                .font(.system(size: 11))
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                .frame(width: 110)
            }

            // Destination folder (only shown in copy mode)
            if viewModel.renameMode == .copyToFolder {
                FolderCard(
                    label: "Destination",
                    icon: "folder.badge.plus",
                    url: viewModel.destinationURL,
                    color: .green
                ) {
                    viewModel.selectDestination()
                }
            }
        }
    }

    // MARK: - Pattern Section

    private var patternSection: some View {
        SettingCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Label("Naming pattern", systemImage: "textformat.abc")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $viewModel.pattern) {
                        ForEach(RenamePattern.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)

                    Spacer()
                }

                // Live example
                HStack(spacing: 6) {
                    Image(systemName: "eye")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text("Example: ")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(viewModel.pattern.description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if viewModel.includeOtherFiles {
                    HStack(spacing: 6) {
                        Image(systemName: "doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text("Other files: ")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        Text("20260312_143522_document.pdf")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Options Row

    private var optionsRow: some View {
        SettingCard {
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    TypeToggle(label: "Photos", icon: "photo", color: .blue, isOn: $viewModel.includePhotos)
                    TypeToggle(label: "Videos", icon: "video", color: .purple, isOn: $viewModel.includeVideos)
                    TypeToggle(label: "Other files", icon: "doc", color: .gray, isOn: $viewModel.includeOtherFiles)

                    Spacer()

                    // Rename mode picker
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.renameMode == .copyToFolder ? "doc.on.doc" : "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentColor)
                        Picker("", selection: $viewModel.renameMode) {
                            ForEach(RenameMode.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                }
            }
        }
    }

    // MARK: - Preview List

    private var previewListHeader: some View {
        HStack {
            Text("Preview (\(previews.count) files)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if previews.count > 200 {
                Text("Showing first 200 files")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var previewList: some View {
        VStack(alignment: .leading, spacing: 8) {
            previewListHeader

            // Table-like list
            VStack(spacing: 0) {
                // Header row
                renameTableHeader

                Divider()

                // Items
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(previews.prefix(200).enumerated()), id: \.element.id) { index, item in
                            RenamePreviewRow(item: item, index: index)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    private var renameTableHeader: some View {
        HStack(spacing: 0) {
            Text("Original")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: 30)
            Text("New Name")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Complete Message

    private var completeMessage: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.errorCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(viewModel.errorCount > 0 ? .orange : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.renameMode == .copyToFolder ? "Copy & rename complete" : "Rename complete")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(viewModel.renamedCount) files \(viewModel.renameMode == .copyToFolder ? "copied" : "renamed")" + (viewModel.errorCount > 0 ? ", \(viewModel.errorCount) errors" : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(viewModel.errorCount > 0 ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Scan & Preview") {
                Task {
                    self.previews = await viewModel.scanAndPreview()
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(viewModel.sourceURL == nil || viewModel.isScanning || viewModel.isRenaming)

            if !previews.isEmpty && !viewModel.renameComplete {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("\(previews.count) files ready")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task { await viewModel.executeRename(items: previews) }
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.renameMode == .copyToFolder ? "Copy & Rename" : "Rename All")
                    Image(systemName: viewModel.renameMode == .copyToFolder ? "doc.on.doc" : "pencil")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(
                previews.isEmpty ||
                viewModel.isRenaming ||
                viewModel.renameComplete ||
                (viewModel.renameMode == .copyToFolder && viewModel.destinationURL == nil)
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Progress Overlay

    private var progressOverlay: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).opacity(0.85)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 12) {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 280)
                    .tint(Color.accentColor)

                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(viewModel.isScanning ? "Scanning files…" : "\(viewModel.renameMode == .copyToFolder ? "Copying" : "Renaming"): \(viewModel.currentFileName)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if viewModel.isRenaming {
                    Text("\(viewModel.currentFileIndex) / \(viewModel.totalFiles)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                
                Button("Cancel") {
                    viewModel.cancelOperation()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            )
        }
    }
}

// MARK: - Preview Row (extracted for type-checker)

private struct RenamePreviewRow: View {
    let item: RenameViewModel.RenamePreview
    let index: Int

    var body: some View {
        let isOther = item.file.mediaType == .other
        let isVideo = item.file.mediaType == .video
        let unchanged = item.originalName == item.newName

        HStack(spacing: 0) {
            Image(systemName: isOther ? "doc" : (isVideo ? "video" : "photo"))
                .font(.system(size: 9))
                .foregroundStyle(isOther ? Color.gray : (isVideo ? Color.purple : Color.blue))
                .frame(width: 18)

            Text(item.originalName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: unchanged ? "equal" : "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(unchanged ? Color.secondary : Color.accentColor)
                .frame(width: 30)

            Text(item.newName)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(unchanged ? .secondary : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            index % 2 == 0
                ? Color.clear
                : Color(NSColor.controlBackgroundColor).opacity(0.4)
        )
    }
}
