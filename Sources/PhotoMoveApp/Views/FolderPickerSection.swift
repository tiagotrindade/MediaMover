import SwiftUI

struct FolderPickerSection: View {
    @Bindable var viewModel: OrganizerViewModel

    var body: some View {
        VStack(spacing: 12) {
            folderRow(
                label: "Source:",
                path: viewModel.sourceURL?.path ?? "No folder selected",
                action: { viewModel.selectSource() }
            )
            folderRow(
                label: "Destination:",
                path: viewModel.destinationURL?.path ?? "No folder selected",
                action: { viewModel.selectDestination() }
            )
        }
        .padding()
    }

    private func folderRow(label: String, path: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .frame(width: 90, alignment: .trailing)
                .fontWeight(.medium)

            Text(path)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)

            Button("Browse...") { action() }
        }
    }
}
