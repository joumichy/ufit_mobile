import SwiftUI

struct UFitCatalogPreparationContent: View {
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onRetry: () -> Void
    private enum Copy { static let title = String(localized: "Produit"); static let loading = String(localized: "Préparation du formulaire"); static let retry = String(localized: "Réessayer") }
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let touch: CGFloat = 44 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack)
            VStack(alignment: .leading, spacing: Layout.gap) {
                if isLoading { ProgressView(Copy.loading) }
                if let message { Text(message).font(.callout) }
                if !isLoading { Button(Copy.retry, action: onRetry).frame(minHeight: Layout.touch) }
            }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
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
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let title: CGFloat = 28 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.header, onBack: onBack).disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    Text(Copy.title).font(.system(size: Layout.title, design: .serif))
                    Text(productName).font(.title3.weight(.medium))
                    Text(Copy.explanation).font(.callout).foregroundStyle(Color.ufitMuted)
                    if let message { Text(message).font(.callout) }
                    if isBusy { ProgressView(Copy.resuming) }
                    else { Button(action: onResume) { Text(Copy.resume).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()) }
                }.padding(Layout.page)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
}
