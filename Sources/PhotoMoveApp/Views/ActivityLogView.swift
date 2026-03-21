import SwiftUI

struct ActivityView: View {
    var organizerVM: OrganizerViewModel

    @State private var filterText: String = ""
    @State private var filterStatus: LogStatus? = nil
    @State private var showNoLogAlert: Bool = false
    @State private var showUpgrade: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            toolbarArea
            Divider()
            if filteredEntries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .task { await organizerVM.loadLog() }
        .alert("No Activity Recorded", isPresented: $showNoLogAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No activity has been logged yet. Organize or rename files first.")
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
    }

    // MARK: - Toolbar

    private var toolbarArea: some View {
        let isPro = ProManager.shared.isPro

        return HStack(spacing: 10) {
            // Search — Pro only
            if isPro {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 12))
                    TextField("Search activity…", text: $filterText)
                        .textFieldStyle(.plain).font(.system(size: 12))
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color(NSColor.controlBackgroundColor)))
                .frame(maxWidth: 220)
            } else {
                Button {
                    showUpgrade = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 12))
                        Text("Search activity…")
                            .foregroundStyle(.tertiary).font(.system(size: 12))
                        Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color(NSColor.controlBackgroundColor)))
                    .frame(maxWidth: 220)
                }
                .buttonStyle(.plain)
            }

            // Filter — Pro only
            if isPro {
                Picker("", selection: $filterStatus) {
                    Text("All").tag(nil as LogStatus?)
                    Text("Success").tag(LogStatus.success as LogStatus?)
                    Text("Warnings").tag(LogStatus.warning as LogStatus?)
                    Text("Errors").tag(LogStatus.error as LogStatus?)
                }
                .labelsHidden().frame(width: 100)
            } else {
                Button {
                    showUpgrade = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Filter")
                            .font(.system(size: 12)).foregroundStyle(.tertiary)
                        Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("\(filteredEntries.count) entries")
                .font(.caption).foregroundStyle(.secondary)

            Button("Clear") { Task { await organizerVM.clearLog() } }
                .buttonStyle(SecondaryButtonStyle()).controlSize(.small)

            // Export — Pro only
            if isPro {
                Button {
                    Task {
                        if let url = await organizerVM.exportLogFile() {
                            if FileManager.default.fileExists(atPath: url.path) {
                                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                            } else {
                                showNoLogAlert = true
                            }
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle()).controlSize(.small).help("Show log file in Finder")
            } else {
                Button {
                    showUpgrade = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Image(systemName: "lock.fill").font(.system(size: 8))
                    }
                }
                .buttonStyle(SecondaryButtonStyle()).controlSize(.small).help("Pro: Export log file")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40)).foregroundStyle(.tertiary)
            Text("No activity yet")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
            Text("Organize or rename files to see history here.")
                .font(.system(size: 12)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Entry list

    private var entryList: some View {
        List(filteredEntries.reversed()) { entry in
            ActivityEntryRow(entry: entry)
        }
        .listStyle(.inset)
    }

    // MARK: - Filter

    private var filteredEntries: [LogEntry] {
        organizerVM.logEntries.filter { entry in
            let matchesStatus = filterStatus == nil || entry.status == filterStatus
            let matchesText = filterText.isEmpty
                || entry.sourcePath.localizedCaseInsensitiveContains(filterText)
                || entry.destinationPath.localizedCaseInsensitiveContains(filterText)
                || entry.action.localizedCaseInsensitiveContains(filterText)
                || (entry.details?.localizedCaseInsensitiveContains(filterText) ?? false)
            return matchesStatus && matchesText
        }
    }
}

// MARK: - Activity Entry Row

struct ActivityEntryRow: View {
    let entry: LogEntry
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                statusIcon.frame(width: 14)
                actionBadge
                Text(URL(fileURLWithPath: entry.sourcePath).lastPathComponent)
                    .font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                Spacer()
                Text(formattedDate)
                    .font(.caption2).foregroundStyle(.tertiary)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 3) {
                    pathRow("From:", entry.sourcePath)
                    if !entry.destinationPath.isEmpty { pathRow("To:", entry.destinationPath) }
                    if let details = entry.details {
                        Text(details).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 22)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 2)
    }

    private func pathRow(_ label: String, _ path: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.tertiary).frame(width: 28, alignment: .leading)
            Text(path).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(2)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch entry.status {
        case .success: Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green).font(.system(size: 12))
        case .warning: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.orange).font(.system(size: 12))
        case .error:   Image(systemName: "xmark.circle.fill").foregroundStyle(Color.red).font(.system(size: 12))
        case .info:    Image(systemName: "info.circle.fill").foregroundStyle(Color.blue).font(.system(size: 12))
        }
    }

    private var actionBadge: some View {
        let color = actionColor(entry.action)
        return Text(entry.action.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.12)))
    }

    private var formattedDate: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: entry.timestamp)
    }

    private func actionColor(_ action: String) -> Color {
        switch action {
        case "copy":            return .blue
        case "move":            return .purple
        case "skip":            return .orange
        case "verify":          return .green
        case "undo-delete", "undo-move": return .cyan
        case "error", "undo-error":      return .red
        case "rename", "rename-copy":    return .indigo
        default:                return .gray
        }
    }
}
