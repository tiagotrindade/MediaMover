import SwiftUI

// MARK: - MoverView (3-panel layout)

struct MoverView: View {
    @Bindable var viewModel: OrganizerViewModel

    var body: some View {
        HStack(spacing: 0) {
            SourcePanel(viewModel: viewModel)
                .frame(minWidth: 180, maxWidth: 300)

            Divider()

            ConfigPanel(viewModel: viewModel)
                .frame(minWidth: 270, maxWidth: 420)

            Divider()

            PreviewPanel(viewModel: viewModel)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    Task { await viewModel.performUndo() }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!viewModel.canUndo || viewModel.isUndoing || viewModel.isProcessing)
                .help("Undo last operation")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.beginOrganizing()
                } label: {
                    HStack(spacing: 5) {
                        Text("Start")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(PrimaryToolbarButtonStyle())
                .disabled(
                    viewModel.discoveredFiles.isEmpty ||
                    viewModel.destinationURL == nil ||
                    viewModel.isProcessing ||
                    viewModel.isScanning
                )
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .task { await viewModel.refreshUndoState() }
        .sheet(isPresented: $viewModel.showDuplicateDialog, onDismiss: {
            viewModel.safeDismissDuplicate()
        }) {
            DuplicateResolverSheet(viewModel: viewModel)
                .interactiveDismissDisabled()
        }
        .sheet(item: $viewModel.result) { result in
            ResultsView(result: result, onDismiss: { viewModel.result = nil })
                .frame(minWidth: 500, minHeight: 400)
        }
        .overlay(alignment: .center) {
            if viewModel.isScanning || viewModel.isProcessing || viewModel.isUndoing {
                ProgressOverlayView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showUpgradeSheet) {
            UpgradeView()
        }
        .alert("Free Version Limit", isPresented: $viewModel.showFileLimitAlert) {
            Button("Continue with first 100") { viewModel.beginOrganizingWithLimit() }
            Button("Upgrade to Pro") { viewModel.showUpgradeSheet = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Free version processes up to 100 files per operation. You have \(viewModel.fileLimitAlertCount) files. Upgrade to Pro for unlimited.")
        }
        .alert("Network Volume Disconnected", isPresented: $viewModel.showDisconnectAlert) {
            Button("Wait for Reconnection") { }
            Button("Cancel Operation", role: .destructive) { viewModel.dismissDisconnectAndCancel() }
        } message: {
            Text("The network volume has been disconnected. The operation is paused and will resume automatically when the volume is available again.")
        }
        .alert("Low Disk Space", isPresented: $viewModel.showSpaceWarning) {
            Button("Continue Anyway") { viewModel.dismissSpaceWarningAndProceed() }
            Button("Cancel", role: .cancel) { viewModel.showSpaceWarning = false }
        } message: {
            Text("The destination volume has only \(viewModel.availableSpaceFormatted) available. Your files total \(viewModel.totalFileSizeFormatted). The operation may fail if space runs out.")
        }
    }
}

// MARK: - Progress Overlay

struct ProgressOverlayView: View {
    var viewModel: OrganizerViewModel

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).opacity(0.85)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 16) {
                if viewModel.isUndoing {
                    ProgressView().controlSize(.large)
                    Text("Undoing last operation…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if viewModel.isDownloadingiCloud {
                    // iCloud download phase
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                            Text("Downloading from iCloud...")
                                .font(.system(size: 13, weight: .medium))
                        }

                        ProgressView(value: viewModel.iCloudDownloadProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 320)
                            .tint(.blue)

                        Text("\(Int(viewModel.iCloudDownloadProgress * Double(viewModel.iCloudFilesToDownload))) / \(viewModel.iCloudFilesToDownload) files")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        Button("Cancel") {
                            viewModel.cancelOperation()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .controlSize(.small)
                    }
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

                        HStack(spacing: 12) {
                            Text("\(viewModel.currentFileIndex) / \(viewModel.totalFiles)")
                                .font(.system(size: 11, design: .monospaced))
                            Text("·").foregroundStyle(.quaternary)
                            Text("\(Int(viewModel.progress * 100))%")
                                .font(.system(size: 11, weight: .medium))
                            if viewModel.filesPerSecond > 0 {
                                Text("·").foregroundStyle(.quaternary)
                                Text(String(format: "%.1f files/s", viewModel.filesPerSecond))
                                    .font(.system(size: 11))
                                if viewModel.estimatedTimeRemaining > 1 {
                                    Text("·").foregroundStyle(.quaternary)
                                    Text("ETA \(formatETA(viewModel.estimatedTimeRemaining))")
                                        .font(.system(size: 11))
                                }
                            }
                            // Transfer speed for network operations
                            if !viewModel.transferSpeedFormatted.isEmpty {
                                Text("·").foregroundStyle(.quaternary)
                                Text(viewModel.transferSpeedFormatted)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .foregroundStyle(.tertiary)

                        Button("Cancel") {
                            viewModel.cancelOperation()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .controlSize(.small)
                    }
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

private func formatETA(_ seconds: TimeInterval) -> String {
    if seconds < 60 { return "\(Int(seconds))s" }
    let m = Int(seconds) / 60
    let s = Int(seconds) % 60
    return "\(m)m \(s)s"
}

// MARK: - Duplicate Resolver Sheet

struct DuplicateResolverSheet: View {
    @Bindable var viewModel: OrganizerViewModel

    var body: some View {
        VStack(spacing: 20) {
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
            HStack(alignment: .top, spacing: 0) {
                FileInfoBox(title: "Incoming", name: viewModel.duplicateSourceName,
                            size: viewModel.duplicateSourceSize, color: .blue)
                Image(systemName: "arrow.right")
                    .font(.caption).foregroundStyle(.tertiary).frame(width: 30).padding(.top, 14)
                FileInfoBox(title: "Existing", name: viewModel.duplicateExistingName,
                            size: viewModel.duplicateExistingSize, color: .orange)
            }
            Toggle("Apply to all remaining duplicates", isOn: $viewModel.applyDuplicateToAll)
                .font(.system(size: 12)).toggleStyle(.checkbox).frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            HStack(spacing: 10) {
                Button("Skip")               { viewModel.resolveDuplicate(action: nil) }
                    .buttonStyle(SecondaryButtonStyle())
                Spacer()
                Button("Rename")             { viewModel.resolveDuplicate(action: .rename) }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Replace")            { viewModel.resolveDuplicate(action: .overwrite) }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Replace if Larger")  { viewModel.resolveDuplicate(action: .overwriteIfLarger) }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

struct FileInfoBox: View {
    let title: String; let name: String; let size: Int64; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(color).textCase(.uppercase)
            Text(name).font(.system(size: 12, weight: .medium)).lineLimit(2)
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.opacity(0.06)))
    }
}

// MARK: - Shared UI Components

struct FolderCard: View {
    let label: String; let icon: String; let url: URL?; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(color).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary).textCase(.uppercase)
                    Text(url?.abbreviatingWithTildeInPath ?? "No folder selected")
                        .font(.system(size: 12)).foregroundStyle(url != nil ? .primary : .secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(url != nil ? color.opacity(0.25) : Color.clear, lineWidth: 1))
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
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(NSColor.controlBackgroundColor)))
    }
}

struct TypeToggle: View {
    let label: String; let icon: String; let color: Color; @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(isOn ? color : Color.secondary)
                Text(label).font(.system(size: 12)).foregroundStyle(isOn ? .primary : .secondary)
            }
        }
        .toggleStyle(.checkbox)
    }
}

struct Badge: View {
    let text: String; var color: Color = .accentColor
    var body: some View {
        Text(text).font(.system(size: 10, weight: .medium)).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(configuration.isPressed ? Color.accentColor.opacity(0.8) : Color.accentColor))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PrimaryToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(configuration.isPressed ? Color.accentColor.opacity(0.8) : Color.accentColor))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - URL Extension

extension URL {
    var abbreviatingWithTildeInPath: String {
        (self.path as NSString).abbreviatingWithTildeInPath
    }

    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
