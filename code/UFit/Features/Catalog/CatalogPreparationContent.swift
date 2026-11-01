import SwiftUI

struct UFitCatalogPreparationContent: View {
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onRetry: () -> Void
    private enum Copy { static let title = String(localized: "Produit"); static let loading = String(localized: "Préparation du formulaire"); static let retry = String(localized: "Réessayer") }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let touch: CGFloat = UFitControlSize.touch }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack)
            VStack(alignment: .leading, spacing: Layout.gap) {
                if isLoading { UFitLoading(Copy.loading) }
                if let message { Text(message).font(UFitTypography.callout) }
                if !isLoading { UFitButton(Copy.retry, action: onRetry).frame(minHeight: Layout.touch) }
            }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
struct UFitCatalogCreationRecoveryContent: View {
    let productName: String
    let isBusy: Bool
    let message: String?
    let onBack: () -> Void
    let onResume: () -> Void
    private enum Copy {
        static let header = String(localized: "Produit")
        static let title = String(localized: "Enregistrement à confirmer")
        static let explanation = String(localized: "Votre demande est conservée. Reprenez-la pour retrouver la fiche ou terminer son enregistrement.")
        static let resume = String(localized: "Reprendre l’enregistrement")
        static let resuming = String(localized: "Vérification de l’enregistrement")
    }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let title: CGFloat = UFitTypography.Size.title }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.header, onBack: onBack).disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    Text(Copy.title).ufitFont(size: Layout.title, design: .serif)
                    Text(productName).font(UFitTypography.title3.weight(.medium))
                    Text(Copy.explanation).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    if let message { Text(message).font(UFitTypography.callout) }
                    if isBusy { UFitLoading(Copy.resuming) }
                    else { UFitButton(action: onResume) { Text(Copy.resume).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary) }
                }.padding(Layout.page)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
