import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentIndex = 0

    private let slides = SampleData.onboardingSlides

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            OnboardingSlideView(slide: slides[currentIndex])
                .animation(.easeInOut(duration: 0.2), value: currentIndex)

            OnboardingProgressIndicator(count: slides.count, currentIndex: currentIndex)
                .padding(.top, 32)

            Spacer(minLength: 40)

            OnboardingActions(
                isLastSlide: currentIndex == slides.count - 1,
                onContinue: continueOnboarding,
                onSkip: onComplete
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

private extension OnboardingView {
    func continueOnboarding() {
        if currentIndex < slides.count - 1 {
            withAnimation(.easeInOut(duration: 0.28)) {
                currentIndex += 1
            }
        } else {
            onComplete()
        }
    }
}

private struct OnboardingSlideView: View {
    let slide: OnboardingSlide

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: slide.systemImage)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Color.ufitInk)
                .frame(width: 96, height: 96)
                .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(spacing: 14) {
                Text(slide.title)
                    .font(.system(size: 31, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.ufitInk)

                Text(slide.description)
                    .font(.system(size: 16))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.ufitMuted)
                    .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: 390)
        .padding(.horizontal, 28)
    }
}

private struct OnboardingProgressIndicator: View {
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.ufitInk : Color.ufitBorder)
                    .frame(width: index == currentIndex ? 32 : 7, height: 7)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: currentIndex)
            }
        }
    }
}

private struct OnboardingActions: View {
    let isLastSlide: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onContinue) {
                Text(isLastSlide ? "Get Started" : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            if !isLastSlide {
                Button("Skip", action: onSkip)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.ufitMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

#Preview {
    OnboardingView {}
}
