import SwiftUI

struct UFitOutfitPreparationContent: View {
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onRetry: () -> Void
    private enum Copy { static let title = String(localized: "Préparer la tenue"); static let loading = String(localized: "Chargement de l’éditeur"); static let retry = String(localized: "Réessayer") }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let touch: CGFloat = UFitControlSize.touch }
    var body: some View {
        VStack(spacing: Layout.gap) {
            DetailHeader(title: Copy.title, onBack: onBack)
            if isLoading { UFitLoading(Copy.loading) }
            if let message { Text(message).font(UFitTypography.callout).padding(.horizontal, Layout.page) }
            if !isLoading { UFitButton(Copy.retry, action: onRetry).frame(minHeight: Layout.touch) }
            Spacer()
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
struct UFitOutfitCreationRecoveryContent: View {
    let title: String
    let isBusy: Bool
    let message: String?
    let onBack: () -> Void
    let onResume: () -> Void
    private enum Copy {
        static let title = String(localized: "Enregistrement interrompu")
        static let explanation = String(localized: "Vérifiez cet enregistrement avant de créer une autre tenue.")
        static let resume = String(localized: "Reprendre l’enregistrement"); static let busy = String(localized: "Vérification du brouillon")
    }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let touch: CGFloat = UFitControlSize.touch }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack).disabled(isBusy)
            VStack(alignment: .leading, spacing: Layout.gap) {
                Text(Copy.title).font(UFitTypography.title2)
                Text(title).font(UFitTypography.headline)
                Text(Copy.explanation).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                if let message { Text(message).font(UFitTypography.callout) }
                if isBusy { UFitLoading(Copy.busy).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                else { UFitButton(action: onResume) { Text(Copy.resume).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary) }
            }.padding(Layout.page)
            Spacer()
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
