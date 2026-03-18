import SwiftUI

struct ResultsView: View {
    let result: OperationResult
    var onDismiss: () -> Void

    private var hasVerificationIssues: Bool {
        result.verificationFailures > 0 || !result.verificationErrors.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            if hasVerificationIssues {
                Label("Operation Complete (with warnings)", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
            } else {
                Label("Operation Complete", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

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
                if result.skippedNoDate > 0 {
                    GridRow {
                        Text("Skipped (no date):")
                        Text("\(result.skippedNoDate)").monospacedDigit().foregroundStyle(.orange)
                    }
                }
                if !result.errors.isEmpty {
                    GridRow {
                        Text("Errors:")
                        Text("\(result.errors.count)").monospacedDigit().foregroundStyle(.red)
                    }
                }

                // Integrity verification results
                if result.verifiedFiles > 0 {
                    GridRow {
                        Text("Integrity verified:")
                        Text("\(result.verifiedFiles)").monospacedDigit().foregroundStyle(.green)
                    }
                }
                if result.verificationFailures > 0 {
                    GridRow {
                        Text("Integrity failures:")
                        Text("\(result.verificationFailures)").monospacedDigit().foregroundStyle(.red)
                    }
                }

                GridRow {
                    Text("Time elapsed:")
                    Text(String(format: "%.1fs", result.elapsedTime)).monospacedDigit()
                }
            }
            .font(.callout)

            // Error details
            if !result.errors.isEmpty {
                DisclosureGroup("Error Details") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(result.errors.prefix(50).enumerated()), id: \.offset) { _, err in
                                Text("\(err.file): \(err.error)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
            }

            // Verification error details
            if !result.verificationErrors.isEmpty {
                DisclosureGroup("Integrity Verification Issues") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(result.verificationErrors.prefix(50).enumerated()), id: \.offset) { _, err in
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                        .font(.caption2)
                                    Text("\(err.file): \(err.error)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
