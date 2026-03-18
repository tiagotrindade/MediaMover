import SwiftUI

struct RenameView: View {
    @Bindable var viewModel: RenameViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left: source files
            RenameSourcePanel(viewModel: viewModel)
                .frame(minWidth: 180, maxWidth: 300)

            Divider()

            // Center: config
            RenameConfigPanel(viewModel: viewModel)
                .frame(minWidth: 250, maxWidth: 380)

            Divider()

            // Right: preview
            RenamePreviewPanel(viewModel: viewModel)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.executeRename() }
                } label: {
                    HStack(spacing: 5) {
                        Text(viewModel.renameMode == .copyToFolder ? "Copy & Rename" : "Rename All")
                        Image(systemName: viewModel.renameMode == .copyToFolder ? "doc.on.doc" : "pencil")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(PrimaryToolbarButtonStyle())
                .disabled(
                    viewModel.previewItems.isEmpty ||
                    viewModel.isRenaming ||
                    viewModel.renameComplete ||
                    (viewModel.renameMode == .copyToFolder && viewModel.destinationURL == nil)
                )
            }
        }
        .overlay(alignment: .center) {
            if viewModel.isScanning || viewModel.isRenaming {
                RenameProgressOverlay(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Rename Source Panel

struct RenameSourcePanel: View {
    @Bindable var viewModel: RenameViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SOURCE")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                Spacer()
                if !viewModel.discoveredFiles.isEmpty {
                    Text("\(viewModel.discoveredFiles.count) files")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            Divider()

            // Folder picker
            Button {
                viewModel.selectSource()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 13)).foregroundStyle(.orange).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Source Folder")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                        Text(viewModel.sourceURL?.abbreviatingWithTildeInPath ?? "Click to select…")
                            .font(.system(size: 11))
                            .foregroundStyle(viewModel.sourceURL != nil ? .primary : .secondary)
                            .lineLimit(2).truncationMode(.middle)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(viewModel.sourceURL != nil ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1))
                )
            }
            .buttonStyle(.plain).padding(10)

            Divider()

            // Footer (subfolders + scan) — always visible below folder picker
            HStack(spacing: 8) {
                Toggle(isOn: $viewModel.includeSubfolders) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.questionmark").font(.system(size: 10))
                        Text("Subfolders").font(.system(size: 11))
                    }
                }
                .toggleStyle(.checkbox)
                Spacer()
                Button("Scan") { Task { await viewModel.scanAndPreview() } }
                    .buttonStyle(SecondaryButtonStyle()).controlSize(.small)
                    .disabled(viewModel.sourceURL == nil || viewModel.isScanning || viewModel.isRenaming)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            Divider()

            // File list
            if viewModel.discoveredFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 28)).foregroundStyle(.tertiary)
                    Text("Scan to see files")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.discoveredFiles.prefix(500).enumerated()), id: \.element.id) { idx, file in
                            SourceFileRow(file: file, index: idx)
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Rename Config Panel

struct RenameConfigPanel: View {
    @Bindable var viewModel: RenameViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Destination (only for copy mode)
                if viewModel.renameMode == .copyToFolder {
                    destinationSection
                }
                patternSection
                optionsSection
                completionBanner
            }
            .padding(14)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Destination")
            Button { viewModel.selectDestination() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13)).foregroundStyle(.green).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Destination Folder")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                        Text(viewModel.destinationURL?.abbreviatingWithTildeInPath ?? "Click to select…")
                            .font(.system(size: 11))
                            .foregroundStyle(viewModel.destinationURL != nil ? .primary : .secondary)
                            .lineLimit(2).truncationMode(.middle)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(viewModel.destinationURL != nil ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var patternSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Naming Pattern")
            VStack(spacing: 0) {
                HStack {
                    Label("Pattern", systemImage: "textformat.abc")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $viewModel.pattern) {
                        ForEach(RenamePattern.allCases) { p in Text(p.displayName).tag(p) }
                    }
                    .labelsHidden().frame(maxWidth: 180)
                    .onChange(of: viewModel.pattern) {
                        if !viewModel.discoveredFiles.isEmpty { viewModel.regeneratePreview() }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                Divider().padding(.horizontal, 10)
                HStack(spacing: 4) {
                    Image(systemName: "eye").font(.system(size: 10)).foregroundStyle(.tertiary)
                    Text("Example: ").font(.system(size: 11)).foregroundStyle(.tertiary)
                    Text(viewModel.pattern.description)
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Options")
            VStack(spacing: 0) {
                HStack {
                    Label("Mode", systemImage: "pencil")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $viewModel.renameMode) {
                        ForEach(RenameMode.allCases, id: \.self) { m in Text(m.rawValue).tag(m) }
                    }
                    .labelsHidden().frame(maxWidth: 180)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                Divider().padding(.horizontal, 10)
                HStack(spacing: 12) {
                    TypeToggle(label: "Photos", icon: "photo", color: .blue, isOn: $viewModel.includePhotos)
                    TypeToggle(label: "Videos", icon: "video", color: .purple, isOn: $viewModel.includeVideos)
                    TypeToggle(label: "Other", icon: "doc", color: .gray, isOn: $viewModel.includeOtherFiles)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                Divider().padding(.horizontal, 10)
                HStack {
                    Label("Fallback date", systemImage: "calendar.badge.exclamationmark")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $viewModel.dateFallback) {
                        ForEach(DateFallback.allCases, id: \.self) { f in Text(f.rawValue).tag(f) }
                    }
                    .labelsHidden().frame(maxWidth: 180)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        }
    }

    @ViewBuilder
    private var completionBanner: some View {
        if viewModel.renameComplete {
            HStack(spacing: 10) {
                Image(systemName: viewModel.errorCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(viewModel.errorCount > 0 ? .orange : .green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.renameMode == .copyToFolder ? "Copy & rename complete" : "Rename complete")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(viewModel.renamedCount) files" + (viewModel.errorCount > 0 ? ", \(viewModel.errorCount) errors" : ""))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset") { viewModel.reset() }.buttonStyle(SecondaryButtonStyle())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(viewModel.errorCount > 0 ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1))
            )
        }
    }
}

// MARK: - Rename Preview Panel

struct RenamePreviewPanel: View {
    var viewModel: RenameViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PREVIEW")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                Spacer()
                if !viewModel.previewItems.isEmpty {
                    Text("\(viewModel.previewItems.count) files")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            Divider()

            if viewModel.previewItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 34)).foregroundStyle(.tertiary)
                    Text("Scan to see preview")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Table header
                HStack(spacing: 0) {
                    Text("ORIGINAL").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.right").font(.system(size: 9)).foregroundStyle(.tertiary).frame(width: 28)
                    Text("NEW NAME").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.previewItems.prefix(300).enumerated()), id: \.element.id) { idx, item in
                            RenamePreviewRow2(item: item, index: idx)
                        }
                    }
                }

                if viewModel.previewItems.count > 300 {
                    Text("Showing 300 of \(viewModel.previewItems.count) files…")
                        .font(.system(size: 10)).foregroundStyle(.tertiary).padding(8)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private struct RenamePreviewRow2: View {
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
                .frame(width: 16)
            Text(item.originalName)
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: unchanged ? "equal" : "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(unchanged ? Color.secondary : Color.accentColor)
                .frame(width: 28)
            Text(item.newName)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(unchanged ? .secondary : .primary)
                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(index % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.4))
    }
}

// MARK: - Rename Progress Overlay

struct RenameProgressOverlay: View {
    var viewModel: RenameViewModel

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).opacity(0.85).ignoresSafeArea()
                .background(.ultraThinMaterial)
            VStack(spacing: 12) {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear).frame(width: 280).tint(Color.accentColor)
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(viewModel.isScanning ? "Scanning files…" : "\(viewModel.renameMode == .copyToFolder ? "Copying" : "Renaming"): \(viewModel.currentFileName)")
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
                if viewModel.isRenaming {
                    Text("\(viewModel.currentFileIndex) / \(viewModel.totalFiles)")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 20, y: 8))
        }
    }
}
