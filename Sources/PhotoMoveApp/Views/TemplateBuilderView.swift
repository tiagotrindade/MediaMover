import SwiftUI

// MARK: - Template Builder View

struct TemplateBuilderView: View {
    @Binding var template: String
    var validation: TemplateValidation
    var previewFiles: [MediaFile]

    @State private var showTokenPalette = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Template input field
            HStack(spacing: 6) {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("e.g. {YYYY}/{MM}/{DD}", text: $template)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                Button {
                    showTokenPalette.toggle()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Insert token")
                .popover(isPresented: $showTokenPalette, arrowEdge: .bottom) {
                    TokenPaletteView(onInsert: { token in
                        template += token.displayLabel
                        showTokenPalette = false
                    })
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                validation.isValid ? Color(NSColor.separatorColor) : Color.red.opacity(0.5),
                                lineWidth: 1
                            )
                    )
            )

            // Validation errors
            if !validation.isValid {
                ForEach(validation.errors, id: \.self) { error in
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9)).foregroundStyle(.red)
                        Text(error)
                            .font(.system(size: 10)).foregroundStyle(.red)
                    }
                }
            }

            // Live preview
            if !template.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Text("Preview").font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary)
                    }

                    let example = TemplateEngine.examplePath(template: template)
                    Text(example)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    // Show first 2 actual file previews if files available
                    if !previewFiles.isEmpty {
                        Divider()
                        ForEach(Array(previewFiles.prefix(2).enumerated()), id: \.offset) { idx, file in
                            let context = file.templateContext(sequenceNumber: idx + 1)
                            let result = TemplateEngine.evaluate(template: template, context: context)
                            HStack(spacing: 4) {
                                Text(file.fileName)
                                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 8)).foregroundStyle(.quaternary)
                                Text(result)
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
            }

            // Preset chips
            presetChips
        }
    }

    private var presetChips: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Presets").font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary)
            FlowLayout(spacing: 4) {
                ForEach(TemplateEngine.folderPresets, id: \.template) { preset in
                    Button {
                        template = preset.template
                    } label: {
                        Text(preset.name)
                            .font(.system(size: 10))
                            .foregroundStyle(template == preset.template ? .white : .secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(
                                Capsule().fill(template == preset.template ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Token Palette

struct TokenPaletteView: View {
    let onInsert: (TemplateToken) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insert Token")
                .font(.system(size: 12, weight: .semibold))

            ForEach(TemplateEngine.availableTokens, id: \.category) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.category.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 4) {
                        ForEach(group.tokens, id: \.displayLabel) { token in
                            Button {
                                onInsert(token)
                            } label: {
                                Text(token.displayLabel)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(token.isLocationToken ? .tertiary : .primary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(tokenColor(for: token).opacity(0.12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .strokeBorder(tokenColor(for: token).opacity(0.2), lineWidth: 0.5)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(token.isLocationToken)
                            .help(token.isLocationToken ? "Coming soon \u{2014} requires GPS data" : token.displayLabel)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    private func tokenColor(for token: TemplateToken) -> Color {
        switch token.category {
        case .date:      return .blue
        case .metadata:  return .purple
        case .file:      return .green
        case .location:  return .orange
        case .separator: return .gray
        }
    }
}

// MARK: - Flow Layout (wrapping horizontal layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                   proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
