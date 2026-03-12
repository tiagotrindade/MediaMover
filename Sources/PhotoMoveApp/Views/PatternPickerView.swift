import SwiftUI

struct PatternPickerView: View {
    @Bindable var viewModel: OrganizerViewModel

    var body: some View {
        HStack {
            Text("Folder Pattern:")
                .frame(width: 110, alignment: .trailing)
                .fontWeight(.medium)

            Picker("", selection: $viewModel.pattern) {
                ForEach(OrganizationPattern.allCases) { pattern in
                    Text(pattern.displayName).tag(pattern)
                }
            }
            .labelsHidden()
            .frame(width: 220)

            Text("e.g. \(viewModel.pattern.examplePath())")
                .foregroundStyle(.secondary)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
