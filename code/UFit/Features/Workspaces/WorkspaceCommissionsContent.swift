import SwiftUI

struct UFitWorkspaceCommissionsContent: View {
    let name: String
    let entries: [UFitWorkspaceCommissionEntry]
    let isLoading: Bool
    let hasLoaded: Bool
    let hasMore: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onRetry: () -> Void
    let onMore: () -> Void
    private enum Copy {
        static let title = String(localized: "Commissions")
        static let refresh = String(localized: "Actualiser les commissions")
        static let loading = String(localized: "Chargement des commissions")
        static let empty = String(localized: "Aucune commission pour le moment.")
        static let retry = String(localized: "Réessayer")
        static let more = String(localized: "Voir les commissions précédentes")
        static let base = String(localized: "Base de calcul")
        static let rate = String(localized: "Taux appliqué à l’achat")
        static let original = String(localized: "Montant d’origine")
        static let adjustments = String(localized: "Ajustements")
        static let net = String(localized: "Après ajustements")
        static let recover = String(localized: "À récupérer sur le montant payé")
        static let details = String(localized: "Détail du calcul")
        static let releaseDate = String(localized: "Fin du délai de retour")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs
        static let touch: CGFloat = UFitControlSize.touch; static let bottom: CGFloat = 32
    }
    private enum Icon { static let refresh = "arrow.clockwise" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if !isLoading { UFitButton(action: onRefresh) { UFitIcon(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Layout.page) {
                    Text(name).font(UFitTypography.title.weight(.medium))
                    if hasLoaded && entries.isEmpty && message == nil && !isLoading { Text(Copy.empty).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: Layout.gap) {
                            Text(entry.net).font(UFitTypography.title2.weight(.medium)).monospacedDigit()
                            Text(entry.releaseSummary).font(UFitTypography.subheadline.weight(.medium))
                            Text(entry.date).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                            UFitDisclosure(Copy.details) {
                                VStack(alignment: .leading, spacing: Layout.gap) {
                                    row(Copy.base, entry.base)
                                    row(Copy.rate, entry.rate)
                                    row(Copy.original, entry.original)
                                    row(Copy.adjustments, entry.adjusted)
                                    row(Copy.net, entry.net)
                                    if entry.hasPaidAdjustment { row(Copy.recover, entry.paidAdjustment) }
                                    if let date = entry.releaseDate { row(Copy.releaseDate, date) }
                                    Text(entry.id).font(UFitTypography.caption.monospaced()).textSelection(.enabled).foregroundStyle(Color.ufitSecondaryText)
                                }.padding(.top, Layout.gap)
                            }.frame(minHeight: Layout.touch)
                        }
                        Divider()
                    }
                    if let message {
                        Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).accessibilityAddTraits(.updatesFrequently)
                        UFitButton(Copy.retry, action: onRetry).frame(minHeight: Layout.touch)
                    }
                    if isLoading || (!hasLoaded && message == nil) { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    else if hasMore && message == nil { UFitButton(Copy.more, action: onMore).frame(minHeight: Layout.touch) }
                }.padding(Layout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func row(_ label: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Layout.gap) { Text(label).fixedSize(); Spacer(); Text(value).monospacedDigit().fixedSize() }
            VStack(alignment: .leading, spacing: Layout.small) { Text(label); Text(value).monospacedDigit() }
        }.font(UFitTypography.subheadline).accessibilityElement(children: .combine)
    }
}
