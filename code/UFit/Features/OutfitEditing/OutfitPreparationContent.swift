import SwiftUI

struct UFitOutfitPreparationContent: View {
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onRetry: () -> Void
    private enum Copy { static let title = String(localized: "Préparer la tenue"); static let loading = String(localized: "Chargement de l’éditeur"); static let retry = String(localized: "Réessayer") }
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let touch: CGFloat = 44 }
    var body: some View {
        VStack(spacing: Layout.gap) {
            DetailHeader(title: Copy.title, onBack: onBack)
            if isLoading { ProgressView(Copy.loading) }
            if let message { Text(message).font(.callout).padding(.horizontal, Layout.page) }
            if !isLoading { Button(Copy.retry, action: onRetry).frame(minHeight: Layout.touch) }
            Spacer()
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
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
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let touch: CGFloat = 44 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack).disabled(isBusy)
            VStack(alignment: .leading, spacing: Layout.gap) {
                Text(Copy.title).font(.title2)
                Text(title).font(.headline)
                Text(Copy.explanation).font(.callout).foregroundStyle(Color.ufitMuted)
                if let message { Text(message).font(.callout) }
                if isBusy { ProgressView(Copy.busy).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                else { Button(action: onResume) { Text(Copy.resume).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()) }
            }.padding(Layout.page)
            Spacer()
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
}
