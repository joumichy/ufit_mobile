import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let slides = [
        OnboardingSlide(id: .zero, systemImage: "sparkles", title: String(localized: "Votre prochaine inspiration."), description: String(localized: "Découvrez des tenues composées par des créateurs et des marques sélectionnés.")),
        OnboardingSlide(id: 1, systemImage: "person.crop.circle.badge.checkmark", title: String(localized: "Des regards singuliers."), description: String(localized: "Explorez les univers des créateurs et retrouvez leurs pièces préférées.")),
        OnboardingSlide(id: 2, systemImage: "bag", title: String(localized: "De la tenue à la pièce."), description: String(localized: "Choisissez vos tailles, vérifiez les conditions de la marque et commandez dans Ufit.")),
        OnboardingSlide(id: 3, systemImage: "bookmark", title: String(localized: "Gardez ce qui vous inspire."), description: String(localized: "Enregistrez vos tenues et retrouvez-les à votre rythme."))
    ]

    var body: some View {
        VStack(spacing: .zero) {
            Spacer(minLength: 60)

            OnboardingSlideView(slide: slides[currentIndex])
                .animation(reduceMotion ? nil : .easeInOut(duration: UFitMotion.transition), value: currentIndex)

            OnboardingProgressIndicator(count: slides.count, currentIndex: currentIndex)
                .padding(.top, UFitSpace.xxl)

            Spacer(minLength: 40)

            OnboardingActions(
                isLastSlide: currentIndex == slides.count - 1,
                onContinue: continueOnboarding,
                onSkip: onComplete
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ufitCanvas)
    }
}

private extension OnboardingView {
    func continueOnboarding() {
        if currentIndex < slides.count - 1 {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: UFitMotion.transition)) {
                currentIndex += 1
            }
        } else {
            onComplete()
        }
    }
}

struct OnboardingSlideView: View {
    let slide: OnboardingSlide

    var body: some View {
        VStack(spacing: UFitSpace.xxl) {
            UFitIcon(systemName: slide.systemImage)
                .ufitFont(size: UFitTypography.Size.display, weight: .light)
                .foregroundStyle(Color.ufitInk)
                .frame(width: 96, height: 96)
                .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.sheet, style: .continuous))

            VStack(spacing: UFitSpace.md) {
                Text(slide.title)
                    .ufitFont(size: UFitTypography.Size.editorial, weight: .regular)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.ufitInk)

                Text(slide.description)
                    .ufitFont(size: UFitTypography.Size.body)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.ufitSecondaryText)
                    .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: 390)
        .padding(.horizontal, 28)
    }
}

struct OnboardingProgressIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: UFitSpace.xs) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.ufitInk : Color.ufitBorder)
                    .frame(width: index == currentIndex ? 32 : 7, height: 7)
                    .animation(reduceMotion ? nil : .easeOut(duration: UFitMotion.feedback), value: currentIndex)
            }
        }
    }
}

struct OnboardingActions: View {
    let isLastSlide: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: UFitSpace.sm) {
            UFitButton(action: onContinue) {
                Text(isLastSlide ? String(localized: "Découvrir Ufit") : String(localized: "Continuer"))
                    .frame(maxWidth: .infinity)
            }
            .ufitButtonStyle(.primary)

            if !isLastSlide {
                UFitButton(String(localized: "Passer"), action: onSkip)
                    .ufitFont(size: UFitTypography.Size.body, weight: .medium)
                    .foregroundStyle(Color.ufitSecondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
        }
        .padding(.horizontal, UFitSpace.xl)
        .padding(.bottom, UFitSpace.xl)
    }
}

#Preview {
    OnboardingView {}
}
