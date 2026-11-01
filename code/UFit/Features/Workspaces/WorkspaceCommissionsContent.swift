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
    }
    private enum Layout {
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8
        static let touch: CGFloat = 44; static let bottom: CGFloat = 32
    }
    private enum Icon { static let refresh = "arrow.clockwise" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                else { Button(action: onRefresh) { Image(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Layout.page) {
                    Text(name).font(.title.weight(.medium))
                    if hasLoaded && entries.isEmpty && message == nil && !isLoading { Text(Copy.empty).font(.callout).foregroundStyle(Color.ufitMuted) }
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: Layout.gap) {
                            Text(entry.date).font(.headline)
                            Text(entry.state.label).font(.subheadline.weight(.medium))
                            Text(entry.net).font(.title2.weight(.medium)).monospacedDigit()
                            DisclosureGroup(Copy.details) {
                                VStack(alignment: .leading, spacing: Layout.gap) {
                                    row(Copy.base, entry.base)
                                    row(Copy.rate, entry.rate)
                                    row(Copy.original, entry.original)
                                    row(Copy.adjustments, entry.adjusted)
                                    row(Copy.net, entry.net)
                                    if entry.hasPaidAdjustment { row(Copy.recover, entry.paidAdjustment) }
                                    Text(entry.id).font(.caption.monospaced()).textSelection(.enabled).foregroundStyle(Color.ufitMuted)
                                }.padding(.top, Layout.gap)
                            }.frame(minHeight: Layout.touch)
                        }
                        Divider()
                    }
                    if let message {
                        Text(message).font(.callout).foregroundStyle(Color.ufitMuted).accessibilityAddTraits(.updatesFrequently)
                        Button(Copy.retry, action: onRetry).frame(minHeight: Layout.touch)
                    }
                    if isLoading || (!hasLoaded && message == nil) { ProgressView(Copy.loading).frame(maxWidth: .infinity) }
                    else if hasMore && message == nil { Button(Copy.more, action: onMore).frame(minHeight: Layout.touch) }
                }.padding(Layout.page).padding(.bottom, Layout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
    private func row(_ label: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Layout.gap) { Text(label).fixedSize(); Spacer(); Text(value).monospacedDigit().fixedSize() }
            VStack(alignment: .leading, spacing: Layout.small) { Text(label); Text(value).monospacedDigit() }
        }.font(.subheadline).accessibilityElement(children: .combine)
    }
}
