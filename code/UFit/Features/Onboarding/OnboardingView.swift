import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentIndex: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let slides = UFitOnboarding.slides
    private enum Layout { static let photoFraction: CGFloat = 0.32 }

    init(initialSlide: OnboardingSlide = .discovery, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _currentIndex = State(initialValue: initialSlide.rawValue)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: .zero) {
                ScrollView {
                    VStack(alignment: .leading, spacing: UFitSpace.xxl) {
                        OnboardingSlideView(slide: slides[currentIndex], imageHeight: geometry.size.height * Layout.photoFraction)
                            .animation(reduceMotion ? nil : .easeInOut(duration: UFitMotion.transition), value: currentIndex)
                        OnboardingProgressIndicator(count: slides.count, currentIndex: currentIndex)
                            .padding(.horizontal, UFitSpace.page)
                    }.padding(.top, UFitSpace.md).padding(.bottom, UFitSpace.xl)
                }.scrollIndicators(.hidden).id(slides[currentIndex].id)

                OnboardingActions(
                    isLastSlide: currentIndex == slides.count - UFitOnboarding.positionStep,
                    onContinue: continueOnboarding,
                    onSkip: onComplete,
                    onBack: currentIndex == UFitOnboarding.initialIndex ? nil : previousSlide
                ).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ufitCanvas)
        }
    }
}

private extension OnboardingView {
    func continueOnboarding() {
        if currentIndex < slides.count - UFitOnboarding.positionStep {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: UFitMotion.transition)) {
                currentIndex += UFitOnboarding.positionStep
            }
        } else {
            onComplete()
        }
    }
    func previousSlide() {
        guard currentIndex > UFitOnboarding.initialIndex else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: UFitMotion.transition)) {
            currentIndex -= UFitOnboarding.positionStep
        }
    }
}

struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    var imageHeight: CGFloat = Layout.image
    @Environment(\.dynamicTypeSize) private var typeSize
    private enum Layout {
        static let image: CGFloat = 280
        static let accessibleImage: CGFloat = 160
        static let lineSpacing: CGFloat = 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xl) {
            FashionImage(source: slide.imageName)
                .frame(maxWidth: .infinity)
                .frame(height: min(imageHeight, typeSize.isAccessibilitySize ? Layout.accessibleImage : Layout.image), alignment: .bottom)
                .clipped().accessibilityHidden(true)

            VStack(alignment: .leading, spacing: UFitSpace.md) {
                Text(slide.title)
                    .font(UFitTypography.editorialTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Color.ufitInk)
                    .accessibilityAddTraits(.isHeader)

                Text(slide.description)
                    .font(UFitTypography.body)
                    .lineSpacing(Layout.lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Color.ufitSecondaryText)
            }.padding(.horizontal, UFitSpace.page)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingProgressIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let count: Int
    let currentIndex: Int
    private enum Layout { static let active: CGFloat = 32; static let inactive: CGFloat = 7; static let height: CGFloat = 7 }
    private enum Copy {
        static let label = String(localized: "Présentation d’Ufit")
        static func step(_ number: Int, count: Int) -> String { String(localized: "Étape \(number) sur \(count)") }
    }

    var body: some View {
        HStack(spacing: UFitSpace.xs) {
            ForEach(.zero..<count, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.ufitInk : Color.ufitBorder)
                    .frame(width: index == currentIndex ? Layout.active : Layout.inactive, height: Layout.height)
                    .animation(reduceMotion ? nil : .easeOut(duration: UFitMotion.feedback), value: currentIndex)
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel(Copy.label)
            .accessibilityValue(Copy.step(currentIndex + UFitOnboarding.positionStep, count: count))
    }
}

struct OnboardingActions: View {
    let isLastSlide: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void
    var onBack: (() -> Void)? = nil
    private enum Copy {
        static let finish = String(localized: "Découvrir Ufit")
        static let next = String(localized: "Continuer")
        static let skip = String(localized: "Passer")
        static let back = String(localized: "Retour")
    }

    var body: some View {
        VStack(spacing: UFitSpace.sm) {
            UFitButton(action: onContinue) {
                Text(isLastSlide ? Copy.finish : Copy.next)
                    .frame(maxWidth: .infinity)
            }
            .ufitButtonStyle(.primary)

            if onBack != nil || !isLastSlide {
                HStack {
                    if let onBack { UFitButton(Copy.back, action: onBack) }
                    Spacer(minLength: UFitSpace.md)
                    if !isLastSlide { UFitButton(Copy.skip, action: onSkip) }
                }.ufitButtonStyle(.text).font(UFitTypography.body).foregroundStyle(Color.ufitSecondaryText)
            }
        }
        .padding(.top, UFitSpace.md)
        .padding(.horizontal, UFitSpace.xl)
        .padding(.bottom, UFitSpace.xl)
        .background(Color.ufitCanvas).overlay(alignment: .top) { Divider() }
    }
}

#Preview {
    OnboardingView {}
}
