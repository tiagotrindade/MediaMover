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
            if !viewModel.discoveredFiles.isEmpty {
                Text("\(viewModel.discoveredFiles.count) files")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
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
            Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10).padding(.vertical, 3)
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
