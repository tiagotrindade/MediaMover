import SwiftUI

struct StatusBarView: View {
    var organizerVM: OrganizerViewModel
    var renameVM: RenameViewModel
    var selection: SidebarItem

    private var totalSize: Int64 {
        organizerVM.discoveredFiles.reduce(0) { $0 + $1.fileSize }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: file count + size
            Group {
                switch selection {
                case .mover where !organizerVM.discoveredFiles.isEmpty:
                    Text("\(organizerVM.discoveredFiles.count) files · \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                case .rename where !renameVM.discoveredFiles.isEmpty:
                    Text("\(renameVM.discoveredFiles.count) files")
                default:
                    Text("")
                }
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)

            Spacer()

            // Center: status
            statusLabel
                .font(.system(size: 11))

            Spacer()

            // Right: version
            Text("v0.9")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 5)
        .frame(height: 26)
        .background(
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(Rectangle().fill(Color(NSColor.separatorColor)).frame(height: 0.5), alignment: .top)
        )
    }

    @ViewBuilder
    private var statusLabel: some View {
        if organizerVM.isScanning || renameVM.isScanning {
            Label("Scanning…", systemImage: "magnifyingglass").foregroundStyle(.blue)
        } else if organizerVM.isProcessing {
            Label("Organizing…", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.blue)
        } else if organizerVM.isUndoing {
            Label("Undoing…", systemImage: "arrow.uturn.backward").foregroundStyle(.orange)
        } else if renameVM.isRenaming {
            Label("Renaming…", systemImage: "pencil").foregroundStyle(.blue)
        } else if let msg = organizerVM.undoMessage {
            Text(msg).foregroundStyle(.secondary)
        } else {
            Text("Ready").foregroundStyle(.secondary)
        }
    }
}
