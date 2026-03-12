import SwiftUI

struct ResultsView: View {
    let result: OperationResult
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Operation Complete", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Files processed:")
                    Text("\(result.processedFiles)").monospacedDigit()
                }
                GridRow {
                    Text("Successful:")
                    Text("\(result.successCount)").monospacedDigit().foregroundStyle(.green)
                }
                if result.skippedDuplicates > 0 {
                    GridRow {
                        Text("Duplicates skipped:")
                        Text("\(result.skippedDuplicates)").monospacedDigit().foregroundStyle(.orange)
                    }
                }
                if !result.errors.isEmpty {
                    GridRow {
                        Text("Errors:")
                        Text("\(result.errors.count)").monospacedDigit().foregroundStyle(.red)
                    }
                }
                GridRow {
                    Text("Time elapsed:")
                    Text(String(format: "%.1fs", result.elapsedTime)).monospacedDigit()
                }
            }
            .font(.callout)

            if !result.errors.isEmpty {
                DisclosureGroup("Error Details") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(result.errors.prefix(50), id: \.file) { err in
                                Text("\(err.file): \(err.error)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
            }

            HStack {
                Spacer()
                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
