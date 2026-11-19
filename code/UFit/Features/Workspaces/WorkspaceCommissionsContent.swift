import SwiftUI

struct UFitWorkspaceCommissionsContent: View {
    let name: String
    @Binding var selectedState: UFitCommissionRelease.State?
    let asOf: UFitTimestamp?
    let entries: [UFitCommissionEntry]
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
        static let sale = String(localized: "Vente")
        static let quantity = String(localized: "Quantité")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs
        static let touch: CGFloat = UFitControlSize.touch; static let bottom: CGFloat = 32
    }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Layout.page) {
                    Text(name).font(UFitTypography.title.weight(.medium))
                    UFitSelection(UFitCommissionLedgerCopy.state, selection: $selectedState, options:
                        [.init(value: Optional<UFitCommissionRelease.State>.none, title: UFitCommissionLedgerCopy.allStates)] +
                        UFitCommissionRelease.State.allCases.map { .init(value: Optional($0), title: UFitCommissionRelease.filterTitle($0)) })
                    if let asOf { Text(UFitCommissionLedgerCopy.asOf(asOf)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                    if hasLoaded && entries.isEmpty && message == nil && !isLoading {
                        UFitEmptyState(title: selectedState == nil ? UFitCommissionLedgerCopy.empty : UFitCommissionLedgerCopy.noMatches,
                            symbol: UFitCommissionLedgerCopy.icon, actionTitle: selectedState == nil ? nil : UFitCommissionLedgerCopy.reset,
                            action: selectedState == nil ? nil : { selectedState = nil })
                    }
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: Layout.page) {
                            VStack(alignment: .leading, spacing: Layout.gap) {
                                VStack(alignment: .leading, spacing: Layout.small) {
                                    Text(entry.productName).font(UFitTypography.headline)
                                    Text(entry.brandName).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                                }
                                Text(entry.net).font(UFitTypography.title2.weight(.medium)).monospacedDigit()
                                Text(entry.releaseSummary).font(UFitTypography.subheadline.weight(.medium))
                                Text(entry.date).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                UFitDisclosure(Copy.details) {
                                    VStack(alignment: .leading, spacing: Layout.gap) {
                                        row(Copy.sale, entry.orderNumber)
                                        row(Copy.quantity, entry.quantity.formatted())
                                        row(Copy.base, entry.base)
                                        row(Copy.rate, entry.rate)
                                        row(Copy.original, entry.original)
                                        row(Copy.adjustments, entry.adjusted)
                                        row(Copy.net, entry.net)
                                        if entry.hasPaidAdjustment { row(Copy.recover, entry.paidAdjustment) }
                                        if let date = entry.releaseDate { row(Copy.releaseDate, date) }
                                    }.padding(.top, Layout.gap)
                                }.frame(minHeight: Layout.touch)
                            }
                            Divider()
                        }
                    }
                    if let message {
                        Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).accessibilityAddTraits(.updatesFrequently)
                        UFitActionButton(title: Copy.retry, kind: .secondary, action: onRetry)
                    }
                    if isLoading || (!hasLoaded && message == nil) { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    else if hasMore && message == nil { UFitActionButton(title: Copy.more, kind: .secondary, action: onMore) }
                }.padding(Layout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable(isEnabled: !isLoading, title: Copy.refresh) { onRefresh() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func row(_ label: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Layout.gap) { Text(label).fixedSize(); Spacer(); Text(value).monospacedDigit().fixedSize() }
            VStack(alignment: .leading, spacing: Layout.small) { Text(label); Text(value).monospacedDigit() }
        }.font(UFitTypography.subheadline).accessibilityElement(children: .combine)
    }
}
