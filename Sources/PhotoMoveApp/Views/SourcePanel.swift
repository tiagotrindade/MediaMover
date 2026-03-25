import SwiftUI

struct SourcePanel: View {
    @Bindable var viewModel: OrganizerViewModel
    @State private var isSourceDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            folderPicker
            Divider()
            panelFooter
            Divider()
            fileListArea
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            Text("SOURCE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Spacer()
            if viewModel.sourceVolumeType != .local {
                VolumeBadge(type: viewModel.sourceVolumeType)
            }
            if !viewModel.discoveredFiles.isEmpty {
                Text("\(viewModel.discoveredFiles.count) files")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    // MARK: - Folder picker

    private var folderPicker: some View {
        Button {
            viewModel.selectSource()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 13)).foregroundStyle(.blue).frame(width: 20)
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
                        .strokeBorder(viewModel.sourceURL != nil ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .padding(10)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .foregroundStyle(Color.accentColor)
                .padding(4)
                .opacity(isSourceDropTargeted ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isSourceDropTargeted)
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, url.isDirectory else { return false }
            viewModel.sourceURL = url
            viewModel.discoveredFiles = []
            viewModel.result = nil
            viewModel.startScan()
            return true
        } isTargeted: {
            isSourceDropTargeted = $0
        }
    }

    // MARK: - File list

    @ViewBuilder
    private var fileListArea: some View {
        if viewModel.sourceURL == nil {
            Spacer()
        } else if viewModel.isScanning {
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(viewModel.scanMessage)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.discoveredFiles.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 28)).foregroundStyle(.tertiary)
                Text("No files found.\nPress Scan to search.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.discoveredFiles.prefix(500).enumerated()), id: \.element.id) { idx, file in
                        SourceFileRow(file: file, index: idx, showThumbnail: viewModel.showThumbnails)
                    }
                    if viewModel.discoveredFiles.count > 500 {
                        Text("+ \(viewModel.discoveredFiles.count - 500) more…")
                            .font(.system(size: 10)).foregroundStyle(.tertiary).padding(8)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var panelFooter: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Toggle(isOn: $viewModel.includeSubfolders) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.questionmark").font(.system(size: 10))
                        Text("Include Subfolders").font(.system(size: 11))
                    }
                }
                .toggleStyle(.checkbox)

                Spacer()

                Toggle(isOn: $viewModel.showThumbnails) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 10))
                        Text("Thumbnails").font(.system(size: 11))
                    }
                }
                .toggleStyle(.checkbox)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider().padding(.horizontal, 8)

            HStack {
                Spacer()
                Button("Scan") {
                    viewModel.startScan()
                }
                .buttonStyle(SecondaryButtonStyle())
                .controlSize(.small)
                .disabled(viewModel.sourceURL == nil || viewModel.isScanning || viewModel.isProcessing || viewModel.isUndoing)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }
}

// MARK: - Source File Row

struct SourceFileRow: View {
    let file: MediaFile
    let index: Int
    var showThumbnail: Bool = true
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 6) {
            if showThumbnail {
                thumbnailView
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                fileIcon.font(.system(size: 12))
                    .frame(width: 20, height: 20)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(file.fileName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary).lineLimit(1)
                if let city = file.locationCity {
                    HStack(spacing: 2) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 7)).foregroundStyle(.orange)
                        Text(city + (file.locationCountry.map { ", \($0)" } ?? ""))
                            .font(.system(size: 9)).foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            if file.iCloudStatus == .notDownloaded {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.blue.opacity(0.6))
                    .help("Not downloaded from iCloud")
            } else if let volType = file.volumeType, volType == .network {
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.system(size: 9))
                    .foregroundStyle(.purple.opacity(0.6))
                    .help("Network volume")
            }
            if file.requiresPro && !ProManager.shared.isPro {
                Text("PRO")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.12)))
            }
            Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10).padding(.vertical, 3)
        .opacity(file.requiresPro && !ProManager.shared.isPro ? 0.6 : 1.0)
        .background(index % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.4))
        .task(id: file.id) {
            guard showThumbnail else { return }
            thumbnail = await ThumbnailService.shared.thumbnail(for: file.url)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumb = thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            fileIcon.font(.system(size: 12)).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }

    @ViewBuilder
    private var fileIcon: some View {
        switch file.mediaType {
        case .photo:
            Image(systemName: "photo").foregroundStyle(Color.blue)
        case .video:
            Image(systemName: "film").foregroundStyle(Color.green)
        case .other:
            Image(systemName: "doc.text").foregroundStyle(Color.gray)
        }
    }
}

// MARK: - Volume Badge

struct VolumeBadge: View {
    let type: VolumeType

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private var icon: String {
        switch type {
        case .network: return "externaldrive.connected.to.line.below"
        case .iCloud:  return "icloud"
        case .local:   return "internaldrive"
        }
    }

    private var label: String {
        switch type {
        case .network: return "NAS"
        case .iCloud:  return "iCloud"
        case .local:   return "Local"
        }
    }

    private var color: Color {
        switch type {
        case .network: return .purple
        case .iCloud:  return .blue
        case .local:   return .secondary
        }
    }
}
