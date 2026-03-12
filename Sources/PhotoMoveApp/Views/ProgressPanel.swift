import SwiftUI

struct ProgressPanel: View {
    var viewModel: OrganizerViewModel

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.progress) {
                HStack {
                    Text("Processing file \(viewModel.currentFileIndex) of \(viewModel.totalFiles)")
                        .font(.callout)
                    Spacer()
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(.callout)
                        .monospacedDigit()
                }
            }

            Text(viewModel.currentFileName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}
