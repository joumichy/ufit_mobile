import SwiftUI

struct UFitOnboardingHost: View {
    let styles: UFitStylePreferencesStore
    let onComplete: () -> Void
    @State private var choosingStyles = false
    @State private var resumeSlide = OnboardingSlide.discovery
    var body: some View {
        if choosingStyles {
            UFitStylePreferencesHost(store: styles, onBack: { choosingStyles = false }, onComplete: onComplete)
        } else {
            OnboardingView(initialSlide: resumeSlide, onComplete: { resumeSlide = .saved; choosingStyles = true }, onSkip: onComplete)
        }
    }
}
