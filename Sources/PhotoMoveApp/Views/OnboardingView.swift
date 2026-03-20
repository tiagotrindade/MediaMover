import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var isPresented: Bool
    var viewModel: OrganizerViewModel

    @State private var currentStep = 0

    private let steps = [
        OnboardingStep(
            icon: "folder.badge.plus",
            iconColor: .blue,
            title: "Choose Source",
            subtitle: "Select the folder containing your photos, videos, or media files.",
            detail: "FolioSort supports RAW, JPEG, HEIC, MP4, MOV, and dozens more formats. Drag & drop a folder or click to browse."
        ),
        OnboardingStep(
            icon: "text.badge.plus",
            iconColor: .purple,
            title: "Pick a Pattern",
            subtitle: "Choose how your files will be organized into folders.",
            detail: "Use presets like YYYY/MM/DD or build a custom template with tokens like {Camera}, {City}, {Original}. See a live preview before committing."
        ),
        OnboardingStep(
            icon: "arrow.right.circle.fill",
            iconColor: .green,
            title: "Organize",
            subtitle: "Copy or move your files with one click. Undo anytime.",
            detail: "FolioSort verifies file integrity after every transfer, handles duplicates intelligently, and keeps a full activity log. You're always in control."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "rectangle.stack.badge.play")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Welcome to FolioSort")
                    .font(.system(size: 22, weight: .bold))
                Text("Organize your media in 3 simple steps")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }
            .padding(.top, 32).padding(.bottom, 24)

            // Step indicators
            HStack(spacing: 20) {
                ForEach(0..<steps.count, id: \.self) { idx in
                    stepIndicator(index: idx)
                }
            }
            .padding(.bottom, 20)

            // Step content
            let step = steps[currentStep]
            VStack(spacing: 14) {
                Image(systemName: step.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(step.iconColor)
                    .frame(height: 50)

                Text(step.title)
                    .font(.system(size: 18, weight: .semibold))

                Text(step.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(step.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation buttons
            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) { currentStep -= 1 }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button("Next") {
                        withAnimation(.easeInOut(duration: 0.2)) { currentStep += 1 }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Get Started") {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        isPresented = false
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(24)
        }
        .frame(width: 500, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func stepIndicator(index: Int) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(index <= currentStep ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    .frame(width: 28, height: 28)
                if index < currentStep {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(index == currentStep ? .white : .secondary)
                }
            }
            Text(steps[index].title)
                .font(.system(size: 10, weight: index == currentStep ? .semibold : .regular))
                .foregroundStyle(index <= currentStep ? .primary : .tertiary)
        }
    }
}

// MARK: - Onboarding Step Model

private struct OnboardingStep {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let detail: String
}
