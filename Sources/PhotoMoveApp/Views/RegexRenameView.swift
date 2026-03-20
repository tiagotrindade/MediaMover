import SwiftUI

// MARK: - Regex Rename Config Section

struct RegexRenameSection: View {
    @Bindable var viewModel: RenameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Custom (Regex)")

            VStack(spacing: 0) {
                // Find field
                configField(label: "Find", icon: "magnifyingglass", placeholder: "Regex pattern (e.g. ^IMG_)") {
                    TextField("", text: $viewModel.regexFind)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .onChange(of: viewModel.regexFind) {
                            if !viewModel.discoveredFiles.isEmpty { viewModel.regeneratePreview() }
                        }
                }

                Divider().padding(.horizontal, 10)

                // Replace field
                configField(label: "Replace", icon: "pencil", placeholder: "Replacement (e.g. $1-$2)") {
                    TextField("", text: $viewModel.regexReplace)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .onChange(of: viewModel.regexReplace) {
                            if !viewModel.discoveredFiles.isEmpty { viewModel.regeneratePreview() }
                        }
                }

                Divider().padding(.horizontal, 10)

                // Options
                HStack(spacing: 14) {
                    Toggle(isOn: $viewModel.regexCaseInsensitive) {
                        Text("Case insensitive").font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: viewModel.regexCaseInsensitive) {
                        if !viewModel.discoveredFiles.isEmpty { viewModel.regeneratePreview() }
                    }

                    Toggle(isOn: $viewModel.regexMatchStemOnly) {
                        Text("Stem only").font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: viewModel.regexMatchStemOnly) {
                        if !viewModel.discoveredFiles.isEmpty { viewModel.regeneratePreview() }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)

                // Error display
                if let error = viewModel.regexError {
                    Divider().padding(.horizontal, 10)
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10)).foregroundStyle(.red)
                        Text(error)
                            .font(.system(size: 10)).foregroundStyle(.red)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                }

                // Match count
                if viewModel.regexError == nil && !viewModel.regexFind.isEmpty {
                    Divider().padding(.horizontal, 10)
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.regexMatchCount > 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(viewModel.regexMatchCount > 0 ? .green : .orange)
                        Text("\(viewModel.regexMatchCount) file\(viewModel.regexMatchCount == 1 ? "" : "s") matched")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))

            // Common patterns dropdown
            commonPatternsSection
        }
    }

    // MARK: - Common Patterns

    private var commonPatternsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Common Patterns").font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary)
            FlowLayout(spacing: 4) {
                ForEach(RenameViewModel.commonRegexPatterns, id: \.name) { pattern in
                    Button {
                        viewModel.regexFind = pattern.find
                        viewModel.regexReplace = pattern.replace
                        if !viewModel.discoveredFiles.isEmpty { viewModel.regeneratePreview() }
                    } label: {
                        Text(pattern.name)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color(NSColor.controlBackgroundColor))
                                    .overlay(Capsule().strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func configField<Content: View>(
        label: String, icon: String, placeholder: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            content()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}

// MARK: - Regex Preview Row (with highlighting)

struct RegexPreviewRow: View {
    let item: RenameViewModel.RenamePreview
    let index: Int
    let matchRanges: [Range<String.Index>]

    var body: some View {
        let isOther = item.file.mediaType == .other
        let isVideo = item.file.mediaType == .video
        let unchanged = item.originalName == item.newName

        HStack(spacing: 0) {
            Image(systemName: isOther ? "doc" : (isVideo ? "video" : "photo"))
                .font(.system(size: 9))
                .foregroundStyle(isOther ? Color.gray : (isVideo ? Color.purple : Color.blue))
                .frame(width: 16)

            // Original name with highlight
            highlightedText(item.originalName, ranges: matchRanges)
                .font(.system(size: 11))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: unchanged ? "equal" : "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(unchanged ? Color.secondary : Color.accentColor)
                .frame(width: 28)

            Text(item.newName)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(unchanged ? .secondary : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(index % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.4))
    }

    /// Renders text with highlighted match ranges in amber/yellow.
    @ViewBuilder
    private func highlightedText(_ text: String, ranges: [Range<String.Index>]) -> some View {
        if ranges.isEmpty {
            Text(text).foregroundStyle(.secondary)
        } else {
            let attributed = buildAttributedString(text, ranges: ranges)
            Text(attributed)
        }
    }

    private func buildAttributedString(_ text: String, ranges: [Range<String.Index>]) -> AttributedString {
        var attr = AttributedString(text)
        attr.foregroundColor = .secondary

        for range in ranges {
            if let attrRange = Range(range, in: attr) {
                attr[attrRange].foregroundColor = .orange
                attr[attrRange].backgroundColor = .orange.opacity(0.15)
            }
        }

        return attr
    }
}
