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
            .padding(.horizontal, 12).padding(.vertical, 10)
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
        .onChange(of: viewModel.renameWithDate)    { viewModel.generatePreview() }
        .onChange(of: viewModel.pattern)           { viewModel.generatePreview() }
        .onChange(of: viewModel.separateByCamera)  { viewModel.generatePreview() }
        .onChange(of: viewModel.separateVideos)    { viewModel.generatePreview() }
        .onChange(of: viewModel.dateFallback)      { viewModel.generatePreview() }
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
        Button {
            viewModel.selectDestination()
        } label: {
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
                viewModel.result = nil
                return true
            } isTargeted: {
                isDestDropTargeted = $0
            }
    }

    // MARK: - Folder Structure

    private var folderStructureSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Folder Structure")
            VStack(spacing: 0) {
                configRow(label: "Pattern", icon: "folder.fill.badge.gearshape") {
                    Picker("", selection: $viewModel.pattern) {
                        ForEach(OrganizationPattern.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .labelsHidden().frame(maxWidth: 180)
                }
                thinDivider
                configRow(label: "Camera subfolder", icon: "camera.fill") {
                    Toggle("", isOn: $viewModel.separateByCamera).labelsHidden().toggleStyle(.checkbox)
                }
                thinDivider
                configRow(label: "Videos subfolder", icon: "video.fill") {
                    Toggle("", isOn: $viewModel.separateVideos).labelsHidden().toggleStyle(.checkbox)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        }
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
                configRow(label: "Rename with date", icon: "textformat") {
                    Toggle("", isOn: $viewModel.renameWithDate).labelsHidden().toggleStyle(.checkbox)
                }
                thinDivider
                HStack(spacing: 12) {
                    TypeToggle(label: "Photos", icon: "photo", color: .blue, isOn: $viewModel.includePhotos)
                    TypeToggle(label: "Videos", icon: "video", color: .green, isOn: $viewModel.includeVideos)
                    TypeToggle(label: "Other", icon: "doc", color: .gray, isOn: $viewModel.includeOtherFiles)
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
                            ForEach(HashAlgorithm.allCases, id: \.self) { a in
                                Text(a.rawValue).tag(a)
                            }
                        }
                        .labelsHidden().frame(maxWidth: 180)
                    }
                }
                thinDivider
                configRow(label: "Duplicates", icon: "doc.on.doc") {
                    Picker("", selection: $viewModel.duplicateStrategy) {
                        ForEach(DuplicateStrategy.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .labelsHidden().frame(maxWidth: 180)
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
