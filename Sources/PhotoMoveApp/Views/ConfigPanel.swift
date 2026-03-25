import SwiftUI

struct ConfigPanel: View {
    @Bindable var viewModel: OrganizerViewModel
    @State private var isDestDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DESTINATION")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            Divider()
            ScrollView {
                VStack(spacing: 18) {
                    destinationCard
                    folderStructureSection
                    fileHandlingSection
                    safetySection
                    metadataSection
                }
                .padding(14)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: viewModel.renameWithDate) {
            if !ProManager.shared.isPro && viewModel.renameWithDate {
                viewModel.renameWithDate = false
                viewModel.showUpgradeSheet = true
            }
            viewModel.generatePreview()
        }
        .onChange(of: viewModel.folderTemplate)    { viewModel.generatePreview() }
        .onChange(of: viewModel.separateVideos) {
            if !ProManager.shared.isPro && viewModel.separateVideos {
                viewModel.separateVideos = false
                viewModel.showUpgradeSheet = true
            }
            viewModel.generatePreview()
        }
        .onChange(of: viewModel.dateFallback)      { viewModel.generatePreview() }
        .onChange(of: viewModel.includeOtherFiles) {
            if !ProManager.shared.isPro && viewModel.includeOtherFiles {
                viewModel.includeOtherFiles = false
                viewModel.showUpgradeSheet = true
            }
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String, icon: String? = nil) -> some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            }
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
            Spacer()
        }
    }

    // MARK: - Destination

    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                viewModel.selectDestination()
            } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 13)).foregroundStyle(.green).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Destination Folder")
                                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                                if viewModel.destVolumeType != .local {
                                    VolumeBadge(type: viewModel.destVolumeType)
                                }
                            }
                            Text(viewModel.destinationURL?.abbreviatingWithTildeInPath ?? "Click to select\u{2026}")
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
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundStyle(Color.accentColor)
                    .padding(2)
                    .opacity(isDestDropTargeted ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isDestDropTargeted)
            )
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first, url.isDirectory else { return false }
                viewModel.destinationURL = url
                viewModel.destVolumeType = VolumeManager.shared.volumeType(for: url)
                viewModel.result = nil
                return true
            } isTargeted: {
                isDestDropTargeted = $0
            }

            // Available space indicator
            if viewModel.destinationURL != nil && !viewModel.availableSpaceFormatted.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.showSpaceWarning ? "exclamationmark.triangle.fill" : "internaldrive")
                        .font(.system(size: 9))
                        .foregroundStyle(viewModel.showSpaceWarning ? .orange : .secondary)
                    Text("\(viewModel.availableSpaceFormatted) available")
                        .font(.system(size: 10))
                        .foregroundStyle(viewModel.showSpaceWarning ? .orange : .secondary)
                    if viewModel.destVolumeType == .iCloud {
                        Text("(depends on iCloud plan)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Folder Structure (Simple + Advanced)

    private var folderStructureSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Folder Structure")

            VStack(spacing: 0) {
                // Simple mode: pattern picker
                simpleFolderPicker

                thinDivider

                // Videos subfolder toggle
                ProLockedRow(gate: .videoSubfolder) {
                    configRow(label: "Videos subfolder", icon: "video.fill") {
                        Toggle("", isOn: $viewModel.separateVideos).labelsHidden().toggleStyle(.checkbox)
                    }
                }

                thinDivider

                // Advanced toggle row
                HStack(spacing: 8) {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: $viewModel.showAdvancedFolderOptions.animation(.easeInOut(duration: 0.2)))
                        .labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))

            // Advanced section (collapsible)
            if viewModel.showAdvancedFolderOptions {
                VStack(alignment: .leading, spacing: 10) {
                    ProfilePickerView(viewModel: viewModel)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                            Text("CUSTOM TEMPLATE")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                            ProInlineBadge(gate: .customTemplates)
                        }

                        ProBadge(gate: .customTemplates) {
                            TemplateBuilderView(
                                template: $viewModel.folderTemplate,
                                validation: viewModel.templateValidation,
                                previewFiles: Array(viewModel.discoveredFiles.prefix(3))
                            )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // Simple folder pattern picker — shows only 3 presets when Free
    private var simpleFolderPicker: some View {
        HStack(spacing: 8) {
            Label("Pattern", systemImage: "folder")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker("", selection: Binding(
                get: { viewModel.folderTemplate },
                set: { viewModel.folderTemplate = $0 }
            )) {
                let isPro = ProManager.shared.isPro
                ForEach(Array(TemplateEngine.folderPresets.enumerated()), id: \.element.template) { index, preset in
                    let isLocked = !isPro && index >= FeatureGate.freeFolderPresetCount
                    HStack {
                        Text(preset.name)
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                        }
                    }
                    .tag(preset.template)
                }
                if !TemplateEngine.folderPresets.contains(where: { $0.template == viewModel.folderTemplate }) {
                    Divider()
                    Text("Custom").tag(viewModel.folderTemplate)
                }
            }
            .labelsHidden().frame(maxWidth: 180)
            .onChange(of: viewModel.folderTemplate) {
                // If Free user selected a Pro preset, reset
                let isPro = ProManager.shared.isPro
                if !isPro {
                    if !OrganizerViewModel.freeFolderTemplates.contains(viewModel.folderTemplate) {
                        viewModel.folderTemplate = "{YYYY}/{MM}/{DD}"
                        viewModel.showUpgradeSheet = true
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    // MARK: - File Handling

    private var fileHandlingSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("File Handling")
            VStack(spacing: 0) {
                HStack {
                    Label("Mode", systemImage: "tray.and.arrow.up")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $viewModel.operationMode) {
                        ForEach(OperationMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 130)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                thinDivider
                ProLockedRow(gate: .renameWithDate) {
                    configRow(label: "Rename with date", icon: "textformat") {
                        Toggle("", isOn: $viewModel.renameWithDate).labelsHidden().toggleStyle(.checkbox)
                    }
                }
                thinDivider
                HStack(spacing: 12) {
                    TypeToggle(label: "Photos", icon: "photo", color: .blue, isOn: $viewModel.includePhotos)
                    TypeToggle(label: "Videos", icon: "video", color: .green, isOn: $viewModel.includeVideos)
                    ProLockedRow(gate: .otherFiles) {
                        TypeToggle(label: "Other", icon: "doc", color: .gray, isOn: $viewModel.includeOtherFiles)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        }
    }

    // MARK: - Safety & Integrity

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Safety & Integrity", icon: "shield")
            VStack(spacing: 0) {
                configRow(label: "Verify after transfer", icon: "checkmark.shield") {
                    Toggle("", isOn: $viewModel.verifyIntegrity).labelsHidden().toggleStyle(.checkbox)
                }
                if viewModel.verifyIntegrity {
                    thinDivider
                    configRow(label: "Algorithm", icon: "cpu") {
                        Picker("", selection: $viewModel.hashAlgorithm) {
                            Text(HashAlgorithm.xxhash64.rawValue).tag(HashAlgorithm.xxhash64)
                            HStack {
                                Text(HashAlgorithm.sha256.rawValue)
                                if !ProManager.shared.isPro {
                                    Image(systemName: "lock.fill").font(.system(size: 8))
                                }
                            }
                            .tag(HashAlgorithm.sha256)
                        }
                        .labelsHidden().frame(maxWidth: 180)
                        .onChange(of: viewModel.hashAlgorithm) {
                            if !ProManager.shared.isPro && viewModel.hashAlgorithm == .sha256 {
                                viewModel.hashAlgorithm = .xxhash64
                                viewModel.showUpgradeSheet = true
                            }
                        }
                    }
                }
                thinDivider
                configRow(label: "Duplicates", icon: "doc.on.doc") {
                    Picker("", selection: $viewModel.duplicateStrategy) {
                        Text(DuplicateStrategy.skip.rawValue).tag(DuplicateStrategy.skip)
                        HStack {
                            Text(DuplicateStrategy.ask.rawValue)
                            if !ProManager.shared.isPro {
                                Image(systemName: "lock.fill").font(.system(size: 8))
                            }
                        }
                        .tag(DuplicateStrategy.ask)
                        HStack {
                            Text(DuplicateStrategy.automatic.rawValue)
                            if !ProManager.shared.isPro {
                                Image(systemName: "lock.fill").font(.system(size: 8))
                            }
                        }
                        .tag(DuplicateStrategy.automatic)
                    }
                    .labelsHidden().frame(maxWidth: 180)
                    .onChange(of: viewModel.duplicateStrategy) {
                        if !ProManager.shared.isPro && viewModel.duplicateStrategy != .skip {
                            viewModel.duplicateStrategy = .skip
                            viewModel.showUpgradeSheet = true
                        }
                    }
                }
                if viewModel.duplicateStrategy == .automatic {
                    thinDivider
                    configRow(label: "Auto action", icon: "arrow.triangle.2.circlepath") {
                        Picker("", selection: $viewModel.duplicateAction) {
                            ForEach(DuplicateAction.allCases, id: \.self) { a in
                                Text(a.rawValue).tag(a)
                            }
                        }
                        .labelsHidden().frame(maxWidth: 180)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        }
    }

    // MARK: - Metadata Fallback

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Metadata Fallback")
            VStack(spacing: 0) {
                configRow(label: "When no EXIF", icon: "calendar.badge.exclamationmark") {
                    Picker("", selection: $viewModel.dateFallback) {
                        ForEach(DateFallback.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .labelsHidden().frame(maxWidth: 180)
                }
                thinDivider
                ProLockedRow(gate: .reverseGeocoding) {
                    configRow(label: "Reverse Geocoding", icon: "location") {
                        Toggle("", isOn: $viewModel.geocodingEnabled).labelsHidden().toggleStyle(.checkbox)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        }
    }

    // MARK: - Helpers

    private var thinDivider: some View {
        Divider().padding(.horizontal, 10)
    }

    private func configRow<Content: View>(
        label: String, icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}
