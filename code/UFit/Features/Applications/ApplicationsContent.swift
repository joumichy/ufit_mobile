import SwiftUI

struct UFitApplicationsContent: View {
    let creator: UFitApplicationDocument?
    let brand: UFitApplicationDocument?
    let canApplyCreator: Bool
    let canApplyBrand: Bool
    let hasLoaded: Bool
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onApply: (UFitApplicationKind) -> Void
    let onCorrect: (UFitApplicationDocument) -> Void
    let onPayments: () -> Void
    var focusedKind: UFitApplicationKind? = nil
    private enum Copy {
        static let title = String(localized: "Mes candidatures")
        static let focusedTitle = String(localized: "Ma candidature")
        static let refresh = String(localized: "Actualiser")
        static let correct = String(localized: "Compléter ma candidature")
        static let feedback = String(localized: "Dernier retour de l’équipe")
        static let submitted = String(localized: "Envoyée le")
        static let payments = String(localized: "Paiements et versements")
        static let anotherBrand = String(localized: "Proposer une autre marque")
        static let newCreator = String(localized: "Présentez votre univers et trois tenues.")
        static let newBrand = String(localized: "Présentez votre marque et ses possibilités de vente.")
    }
    private enum Layout { static let spacing: CGFloat = UFitSpace.xl; static let inline: CGFloat = 12; static let radius: CGFloat = UFitRadius.card; static let bottom: CGFloat = 110; static let title: CGFloat = UFitTypography.Size.editorial; static let touch: CGFloat = UFitControlSize.touch }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) { if isLoading { UFitLoading().frame(minWidth: Layout.touch, minHeight: Layout.touch) } }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    Text(focusedKind == nil ? Copy.title : Copy.focusedTitle).ufitFont(size: Layout.title, design: .serif).accessibilityAddTraits(.isHeader)
                    if let message {
                        Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        UFitActionButton(title: Copy.refresh, kind: .secondary, disabled: isLoading, action: onRefresh)
                    }
                    if hasLoaded {
                        if let focusedKind { card(focusedKind, focusedKind == .creator ? creator : brand, canApply: false) }
                        else {
                            card(.creator, creator, canApply: canApplyCreator)
                            card(.brand, brand, canApply: canApplyBrand)
                        }
                    }
                }.padding(Layout.spacing).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable(isEnabled: !isLoading, title: Copy.refresh) { onRefresh() }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func card(_ kind: UFitApplicationKind, _ application: UFitApplicationDocument?, canApply: Bool) -> some View {
        VStack(alignment: .leading, spacing: Layout.inline) {
            Text(kind.label).font(UFitTypography.title2.weight(.medium))
            if let application {
                Text(application.name).font(UFitTypography.headline)
                Text(application.metadata.status.label).font(UFitTypography.subheadline.weight(.semibold))
                Text(Copy.submitted + " " + application.metadata.submittedAt.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                if let review = application.metadata.latestReview, let notes = review.notes {
                    Divider()
                    Text(Copy.feedback).font(UFitTypography.subheadline.weight(.medium))
                    Text(notes).font(UFitTypography.callout)
                    Text(review.createdAt.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                }
                if application.metadata.status.canCorrect {
                    UFitButton(action: { onCorrect(application) }) { Text(Copy.correct).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary)
                }
                if application.metadata.status == .accepted {
                    UFitButton(Copy.payments, action: onPayments).frame(minHeight: Layout.touch)
                    if kind == .brand && canApply { UFitActionButton(title: Copy.anotherBrand, kind: .secondary) { onApply(kind) } }
                }
            } else if canApply {
                Text(kind == .creator ? Copy.newCreator : Copy.newBrand).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                UFitButton(action: { onApply(kind) }) { Text(kind.title).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary)
            }
        }.padding(Layout.spacing).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ufitCanvas, in: RoundedRectangle(cornerRadius: Layout.radius))
    }
}
