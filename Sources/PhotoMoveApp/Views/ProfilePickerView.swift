import SwiftUI

// MARK: - Profile Picker View

struct ProfilePickerView: View {
    var viewModel: OrganizerViewModel
    @State private var profileManager = ProfileManager.shared
    @State private var showSaveSheet = false
    @State private var showDeleteConfirm = false
    @State private var newProfileName = ""
    @State private var profileToDelete: OrganizerProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "tray.2")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Text("PRESETS")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                Spacer()
            }

            HStack(spacing: 6) {
                Picker("", selection: Binding(
                    get: { profileManager.selectedProfileId },
                    set: { id in
                        if let id, let profile = profileManager.profiles.first(where: { $0.id == id }) {
                            profileManager.applyProfile(profile, to: viewModel)
                        }
                    }
                )) {
                    Text("Custom").tag(nil as UUID?)
                    Divider()
                    ForEach(profileManager.profiles) { profile in
                        HStack {
                            if profile.isBuiltIn {
                                Image(systemName: "lock.fill")
                            }
                            Text(profile.name)
                        }
                        .tag(profile.id as UUID?)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)

                // Save as button
                Button {
                    newProfileName = ""
                    showSaveSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Save current settings as preset")

                // Delete button (only for user presets)
                if let selected = profileManager.selectedProfile, !selected.isBuiltIn {
                    Button {
                        profileToDelete = selected
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11)).foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete this preset")
                }

                // Duplicate button (for built-in presets)
                if let selected = profileManager.selectedProfile, selected.isBuiltIn {
                    Button {
                        let copy = profileManager.duplicateProfile(selected)
                        profileManager.selectedProfileId = copy.id
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .help("Duplicate & customize this preset")
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor))
            )
        }
        .popover(isPresented: $showSaveSheet) {
            SavePresetSheet(
                name: $newProfileName,
                onSave: {
                    let profile = profileManager.profileFromViewModel(viewModel, name: newProfileName)
                    profileManager.addProfile(profile)
                    profileManager.selectedProfileId = profile.id
                    showSaveSheet = false
                },
                onCancel: { showSaveSheet = false }
            )
        }
        .alert("Delete Preset?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    profileManager.deleteProfile(profile)
                }
            }
        } message: {
            if let profile = profileToDelete {
                Text("Are you sure you want to delete \"\(profile.name)\"?")
            }
        }
    }
}

// MARK: - Save Preset Sheet

private struct SavePresetSheet: View {
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Save Preset")
                .font(.system(size: 14, weight: .semibold))

            TextField("Preset name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            HStack(spacing: 10) {
                Button("Cancel") { onCancel() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Save") { onSave() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
    }
}
