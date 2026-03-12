import SwiftUI

struct ActivityLogView: View {
    @Bindable var viewModel: OrganizerViewModel
    @State private var filterText: String = ""
    @State private var filterStatus: LogStatus? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Activity Log")
                    .font(.headline)

                Spacer()

                // Filter by status
                Picker("Filter", selection: $filterStatus) {
                    Text("All").tag(nil as LogStatus?)
                    Text("Success").tag(LogStatus.success as LogStatus?)
                    Text("Warnings").tag(LogStatus.warning as LogStatus?)
                    Text("Errors").tag(LogStatus.error as LogStatus?)
                    Text("Info").tag(LogStatus.info as LogStatus?)
                }
                .frame(width: 120)

                Button("Clear Log") {
                    Task { await viewModel.clearLog() }
                }

                Button {
                    Task {
                        if let url = await viewModel.exportLogFile() {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Show log file in Finder")
            }
            .padding()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search...", text: $filterText)
                    .textFieldStyle(.roundedBorder)

                Text("\(filteredEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Log entries
            if filteredEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No log entries")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredEntries.reversed()) { entry in
                    logEntryRow(entry)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await viewModel.loadLog()
        }
    }

    private var filteredEntries: [LogEntry] {
        viewModel.logEntries.filter { entry in
            let matchesStatus = filterStatus == nil || entry.status == filterStatus
            let matchesText = filterText.isEmpty
                || entry.sourcePath.localizedCaseInsensitiveContains(filterText)
                || entry.destinationPath.localizedCaseInsensitiveContains(filterText)
                || entry.action.localizedCaseInsensitiveContains(filterText)
                || (entry.details?.localizedCaseInsensitiveContains(filterText) ?? false)
            return matchesStatus && matchesText
        }
    }

    private func logEntryRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            statusIcon(entry.status)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.action.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(actionColor(entry.action).opacity(0.15))
                        .foregroundStyle(actionColor(entry.action))
                        .cornerRadius(3)

                    Spacer()

                    Text(formattedDate(entry.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(entry.sourcePath)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if !entry.destinationPath.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                        Text(entry.destinationPath)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundStyle(.secondary)
                }

                if let details = entry.details {
                    Text(details)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func statusIcon(_ status: LogStatus) -> some View {
        switch status {
        case .success:
            return Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .warning:
            return Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .error:
            return Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .info:
            return Image(systemName: "info.circle.fill").foregroundStyle(.blue)
        }
    }

    private func actionColor(_ action: String) -> Color {
        switch action {
        case "copy": return .blue
        case "move": return .purple
        case "skip": return .orange
        case "verify": return .green
        case "undo-delete", "undo-move": return .cyan
        case "error", "undo-error": return .red
        default: return .gray
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }
}
