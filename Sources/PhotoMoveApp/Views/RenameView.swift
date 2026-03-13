import SwiftUI

struct RenameView: View {
    @State private var viewModel = RenameViewModel()

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
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Divider()

                ScrollView {
                    VStack(spacing: 16) {
                        // Folder card
                        folderCard
                        // Pattern picker
                        patternSection
                        // File types
                        typesRow
                        // Preview list
                        if !viewModel.previewItems.isEmpty {
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
    }

    // MARK: - Folder Card

    private var folderCard: some View {
        FolderCard(
            label: "Folder",
            icon: "folder",
            url: viewModel.sourceURL,
            color: .orange
        ) {
            viewModel.selectSource()
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
            }
        }
        .onChange(of: viewModel.pattern) {
            if !viewModel.discoveredFiles.isEmpty {
                Task { await viewModel.scanAndPreview() }
            }
        }
    }

    // MARK: - Types Row

    private var typesRow: some View {
        SettingCard {
            HStack(spacing: 14) {
                TypeToggle(label: "Photos", icon: "photo", color: .blue, isOn: $viewModel.includePhotos)
                TypeToggle(label: "Videos", icon: "video", color: .purple, isOn: $viewModel.includeVideos)
                Spacer()
            }
        }
    }

    // MARK: - Preview List

    private var previewList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preview (\(viewModel.previewItems.count) files)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Table-like list
            VStack(spacing: 0) {
                // Header row
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

                Divider()

                // Items (show first 200)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.previewItems.prefix(200)) { item in
                            HStack(spacing: 0) {
                                Text(item.originalName)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 30)

                                Text(item.newName)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                viewModel.previewItems.firstIndex(where: { $0.id == item.id })! % 2 == 0
                                    ? Color.clear
                                    : Color(NSColor.controlBackgroundColor).opacity(0.4)
                            )
                        }
                    }
                }
                .frame(maxHeight: 250)

                if viewModel.previewItems.count > 200 {
                    Text("Showing 200 of \(viewModel.previewItems.count) files…")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(8)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    // MARK: - Complete Message

    private var completeMessage: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.errorCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(viewModel.errorCount > 0 ? .orange : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rename complete")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(viewModel.renamedCount) files renamed" + (viewModel.errorCount > 0 ? ", \(viewModel.errorCount) errors" : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reset") {
                viewModel.reset()
            }
            .buttonStyle(SecondaryButtonStyle())
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
                Task { await viewModel.scanAndPreview() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(viewModel.sourceURL == nil || viewModel.isScanning || viewModel.isRenaming)

            if !viewModel.previewItems.isEmpty && !viewModel.renameComplete {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("\(viewModel.previewItems.count) files ready to rename")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                Task { await viewModel.executeRename() }
            } label: {
                HStack(spacing: 6) {
                    Text("Rename All")
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.previewItems.isEmpty || viewModel.isRenaming || viewModel.renameComplete)
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
                    Text(viewModel.isScanning ? "Scanning files…" : "Renaming: \(viewModel.currentFileName)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if viewModel.isRenaming {
                    Text("\(viewModel.currentFileIndex) / \(viewModel.totalFiles)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
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
