import SwiftUI

// MARK: - Main View

struct MainView: View {
    @State private var viewModel = OrganizerViewModel()
    @State private var showAdvanced = false
    @State private var discoveredFiles: [MediaFile] = []

    var body: some View {
        ZStack {
            // Background
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider()

                ScrollView {
                    VStack(spacing: 16) {
                        folderCards
                        patternRow
                        modeAndTypesRow
                        advancedSection
                    }
                    .padding(20)
                }

                Divider()
                bottomBar
            }
        }
        .frame(minWidth: 680, minHeight: 500)
        .task { await viewModel.refreshUndoState() }
        // Sheets
        .sheet(isPresented: $viewModel.showLogSheet) {
            logSheet
        }
        .sheet(isPresented: $viewModel.showDuplicateDialog) {
            DuplicateResolverSheet(viewModel: viewModel)
        }
        // Overlay: scanning / processing / undo
        .overlay(alignment: .center) {
            if viewModel.isScanning || viewModel.isProcessing || viewModel.isUndoing {
                progressOverlay
            }
        }
        // Results sheet
        .sheet(item: $viewModel.result) { result in
            ResultsView(result: result, onDismiss: { viewModel.result = nil })
                .frame(minWidth: 500, minHeight: 400)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            // App icon + name
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("MediaMover")
                    .font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            // Undo message
            if let msg = viewModel.undoMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Action buttons
            HStack(spacing: 4) {
                HeaderButton(icon: "arrow.uturn.backward", tooltip: "Undo last operation") {
                    Task { await viewModel.performUndo() }
                }
                .disabled(!viewModel.canUndo || viewModel.isUndoing || viewModel.isProcessing)

                HeaderButton(icon: "list.bullet.rectangle", tooltip: "Activity log") {
                    Task {
                        await viewModel.loadLog()
                        viewModel.showLogSheet = true
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Folder Cards

    private var folderCards: some View {
        HStack(spacing: 12) {
            FolderCard(
                label: "Source",
                icon: "folder",
                url: viewModel.sourceURL,
                color: .blue
            ) {
                viewModel.selectSource()
                discoveredFiles = []
                viewModel.result = nil
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 20)

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

    // MARK: - Pattern Row

    private var patternRow: some View {
        SettingCard {
            HStack(spacing: 12) {
                Label("Folder pattern", systemImage: "folder.fill.badge.gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 140, alignment: .leading)

                Picker("", selection: $viewModel.pattern) {
                    ForEach(OrganizationPattern.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .labelsHidden()
                .frame(width: 180)

                Spacer()

                // Live example
                if let src = viewModel.sourceURL {
                    let example = viewModel.pattern.examplePath()
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.square")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(src.lastPathComponent + "/" + example + "/photo.jpg")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Mode & Types Row

    private var modeAndTypesRow: some View {
        SettingCard {
            HStack(spacing: 20) {
                // Copy / Move segmented
                HStack(spacing: 6) {
                    Label("Mode", systemImage: "tray.and.arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $viewModel.operationMode) {
                        ForEach(OperationMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 130)
                }

                Divider().frame(height: 18)

                // File types
                HStack(spacing: 14) {
                    TypeToggle(label: "Photos", icon: "photo", color: .blue, isOn: $viewModel.includePhotos)
                    TypeToggle(label: "Videos", icon: "video", color: .purple, isOn: $viewModel.includeVideos)
                    TypeToggle(label: "Other", icon: "doc", color: .gray, isOn: $viewModel.includeOtherFiles)
                }

                Spacer()
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(spacing: 0) {
            // Toggle header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showAdvanced ? 90 : 0))

                    Text("Advanced Settings")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !showAdvanced {
                        advancedSummaryBadges
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
            }
            .buttonStyle(.plain)

            if showAdvanced {
                advancedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Small summary of active non-default settings
    private var advancedSummaryBadges: some View {
        HStack(spacing: 6) {
            if viewModel.renameWithDate    { Badge(text: "Rename") }
            if viewModel.separateByCamera  { Badge(text: "Camera") }
            if !viewModel.separateVideos   { Badge(text: "No Videos/", color: .orange) }
            if !viewModel.verifyIntegrity  { Badge(text: "No verify", color: .orange) }
            if viewModel.duplicateStrategy != .ask { Badge(text: viewModel.duplicateStrategy.rawValue) }
        }
    }

    private var advancedContent: some View {
        VStack(spacing: 10) {
            // Duplicates
            AdvancedRow(label: "Duplicates", icon: "doc.on.doc") {
                HStack(spacing: 8) {
                    Picker("", selection: $viewModel.duplicateStrategy) {
                        ForEach(DuplicateStrategy.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 145)

                    if viewModel.duplicateStrategy == .automatic {
                        Picker("", selection: $viewModel.duplicateAction) {
                            ForEach(DuplicateAction.allCases, id: \.self) { a in
                                Text(a.rawValue).tag(a)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 155)
                    }
                }
            }

            // No metadata fallback
            AdvancedRow(label: "No metadata on file", icon: "calendar.badge.exclamationmark") {
                Picker("", selection: $viewModel.dateFallback) {
                    ForEach(DateFallback.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .labelsHidden()
                .frame(width: 195)
            }

            // Subfolders + rename
            AdvancedRow(label: "Organisation", icon: "folder.badge.gearshape") {
                HStack(spacing: 16) {
                    AdvancedToggle(label: "Videos subfolder", icon: "video.fill", isOn: $viewModel.separateVideos)
                        .help("e.g. 2026/03/12/Videos/")
                    AdvancedToggle(label: "Camera subfolder", icon: "camera.fill", isOn: $viewModel.separateByCamera)
                        .help("e.g. 2026/03/12/iPhone 15 Pro/")
                    AdvancedToggle(label: "Rename with date", icon: "textformat", isOn: $viewModel.renameWithDate)
                        .help("e.g. 20260312_143522_photo.jpg")
                }
            }

            // Integrity
            AdvancedRow(label: "Integrity", icon: "checkmark.shield") {
                HStack(spacing: 10) {
                    Toggle("Verify after copy", isOn: $viewModel.verifyIntegrity)
                        .font(.system(size: 12))
                        .toggleStyle(.checkbox)

                    if viewModel.verifyIntegrity {
                        Picker("", selection: $viewModel.hashAlgorithm) {
                            ForEach(HashAlgorithm.allCases, id: \.self) { a in
                                Text(a.rawValue).tag(a)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Scan") {
                Task { discoveredFiles = await viewModel.scanFiles() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(viewModel.sourceURL == nil || viewModel.isScanning || viewModel.isProcessing)
            .keyboardShortcut("r", modifiers: .command)

            // File count summary
            if !discoveredFiles.isEmpty {
                let photos = discoveredFiles.filter { $0.mediaType == .photo }.count
                let videos = discoveredFiles.filter { $0.mediaType == .video }.count
                let other  = discoveredFiles.filter { $0.mediaType == .other }.count
                let parts  = [
                    photos > 0 ? "\(photos) photos" : nil,
                    videos > 0 ? "\(videos) videos" : nil,
                    other  > 0 ? "\(other) other"  : nil,
                ].compactMap { $0 }.joined(separator: "  ·  ")

                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text(parts)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }

            Spacer()

            Button {
                Task { await viewModel.startOrganizing(files: discoveredFiles) }
            } label: {
                HStack(spacing: 6) {
                    Text("Organize")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(
                discoveredFiles.isEmpty ||
                viewModel.destinationURL == nil ||
                viewModel.isProcessing ||
                viewModel.isScanning
            )
            .keyboardShortcut(.return, modifiers: .command)
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

            VStack(spacing: 16) {
                if viewModel.isUndoing {
                    ProgressView()
                        .controlSize(.large)
                    Text("Undoing last operation…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ProgressView(value: viewModel.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 320)
                            .tint(Color.accentColor)

                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(viewModel.isScanning ? viewModel.scanMessage : viewModel.currentFileName)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 300, alignment: .leading)
                        }

                        if !viewModel.isScanning {
                            Text("\(viewModel.currentFileIndex) / \(viewModel.totalFiles) files")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Button("Cancel") {
                        viewModel.cancelOperation()
                    }
                    .buttonStyle(SecondaryButtonStyle())
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

    // MARK: - Log Sheet

    private var logSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Activity Log")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Close") { viewModel.showLogSheet = false }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            Divider()
            ActivityLogView(viewModel: viewModel)
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Supporting Views

struct FolderCard: View {
    let label: String
    let icon: String
    let url: URL?
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    Text(url?.abbreviatingWithTildeInPath ?? "No folder selected")
                        .font(.system(size: 12))
                        .foregroundStyle(url != nil ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                url != nil ? color.opacity(0.25) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct SettingCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
    }
}

struct TypeToggle: View {
    let label: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(isOn ? color : Color.secondary)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(isOn ? .primary : .secondary)
            }
        }
        .toggleStyle(.checkbox)
    }
}

struct AdvancedRow<Content: View>: View {
    let label: String
    let icon: String
    let content: Content

    init(label: String, icon: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 10) {
            Label(label, systemImage: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 138, alignment: .leading)
                .lineLimit(1)

            content

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
        )
    }
}

struct AdvancedToggle: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 4) {
                Image(systemName: isOn ? icon : icon)
                    .font(.system(size: 10))
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(isOn ? .primary : .secondary)
            }
        }
        .toggleStyle(.checkbox)
    }
}

struct HeaderButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

struct Badge: View {
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.cornerRadius(4))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.8) : Color.accentColor)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Duplicate Resolver Sheet

struct DuplicateResolverSheet: View {
    @Bindable var viewModel: OrganizerViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duplicate File Found")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Choose how to handle this file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // File comparison
            HStack(alignment: .top, spacing: 0) {
                FileInfoBox(
                    title: "Incoming",
                    name: viewModel.duplicateSourceName,
                    size: viewModel.duplicateSourceSize,
                    color: .blue
                )
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 30)
                    .padding(.top, 14)
                FileInfoBox(
                    title: "Existing",
                    name: viewModel.duplicateExistingName,
                    size: viewModel.duplicateExistingSize,
                    color: .orange
                )
            }

            Toggle("Remember this choice for all remaining duplicates in this session", isOn: $viewModel.applyDuplicateToAll)
                .font(.system(size: 12))
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help("If you select this, the app won't ask you again for other duplicates found in this same operation.")

            Divider()

            // Actions
            HStack(spacing: 10) {
                Button("Skip") { viewModel.resolveDuplicate(action: nil) }
                    .buttonStyle(SecondaryButtonStyle())
                Spacer()
                Button("Rename")         { viewModel.resolveDuplicate(action: .rename) }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Replace")        { viewModel.resolveDuplicate(action: .overwrite) }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Replace if Larger") { viewModel.resolveDuplicate(action: .overwriteIfLarger) }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

struct FileInfoBox: View {
    let title: String
    let name: String
    let size: Int64
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .textCase(.uppercase)
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.06))
        )
    }
}

// MARK: - URL extension

private extension URL {
    var abbreviatingWithTildeInPath: String {
        (self.path as NSString).abbreviatingWithTildeInPath
    }
}
