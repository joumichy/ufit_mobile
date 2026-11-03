import SwiftUI

struct UFitWorkspaceDashboardContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.ufitPrimarySection) private var isPrimarySection
    let document: UFitWorkspaceDashboardPresentation?
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onCommissions: () -> Void
    var sectionTitle: String = Copy.title
    var showsActivity = true
    private enum Copy {
        static let title = String(localized: "Tableau de bord")
        static let refresh = String(localized: "Actualiser le tableau de bord")
        static let loading = String(localized: "Chargement du tableau de bord")
        static let retry = String(localized: "Réessayer")
        static let sales = String(localized: "Ventes")
        static let attributed = String(localized: "Ventes attribuées")
        static let orderBasis = String(localized: "Livraison et taxes incluses")
        static let merchandiseBasis = String(localized: "Pièces attribuées, hors livraison et taxes")
        static let noSales = String(localized: "Aucun encaissement pour le moment.")
        static let captured = String(localized: "Encaissé")
        static let refunded = String(localized: "Remboursé")
        static let inProgress = String(localized: "Remboursement en cours")
        static let net = String(localized: "Net après remboursements")
        static let activity = String(localized: "Activité")
        static let commissions = String(localized: "Commissions")
        static let noCommissions = String(localized: "Aucune commission pour le moment.")
        static let original = String(localized: "Montant d’origine")
        static let adjustments = String(localized: "Ajustements")
        static let commissionNet = String(localized: "Après ajustements")
        static let estimated = String(localized: "Estimées")
        static let pending = String(localized: "En attente")
        static let validated = String(localized: "Disponibles pour versement")
        static let paid = String(localized: "Payées")
        static let recover = String(localized: "À récupérer sur les commissions payées")
        static let ledger = String(localized: "Historique des commissions")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs
        static let radius: CGFloat = UFitRadius.card; static let touch: CGFloat = UFitControlSize.touch; static let bottom: CGFloat = 32; static let rootBottom: CGFloat = 110
        static let singleColumn = [GridItem(.flexible(), alignment: .topLeading)]
        static let columns = [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)]
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let next = "chevron.right" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: sectionTitle, onBack: onBack) {
                if !isLoading { UFitButton(action: onRefresh) { UFitIcon(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let message {
                        Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).accessibilityAddTraits(.updatesFrequently)
                        UFitActionButton(title: Copy.retry, kind: .secondary, action: onRefresh)
                    }
                    if let document {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(document.name).font(UFitTypography.title.weight(.medium))
                            Text(document.status).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                            if let grade = document.grade { Text(grade).font(UFitTypography.subheadline.weight(.medium)) }
                        }
                        if showsActivity { activity(document.activity) }
                        sales(document)
                        if document.kind == .creator { commissions(document.commissions) }
                    } else if isLoading || message == nil { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                }.padding(Layout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func activity(_ rows: [UFitWorkspaceActivityFigure]) -> some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.activity).font(UFitTypography.title2.weight(.medium))
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? Layout.singleColumn : Layout.columns, spacing: Layout.gap) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(row.value, format: .number).font(UFitTypography.title2.weight(.medium)).monospacedDigit()
                        Text(row.label).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(Layout.gap)
                        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: Layout.radius))
                        .accessibilityElement(children: .combine)
                }
            }
        }
    }
    private func sales(_ document: UFitWorkspaceDashboardPresentation) -> some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            VStack(alignment: .leading, spacing: Layout.small) {
                Text(document.kind == .creator ? Copy.attributed : Copy.sales).font(UFitTypography.title2.weight(.medium))
                Text(document.kind == .creator ? Copy.merchandiseBasis : Copy.orderBasis).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            }
            if document.sales.isEmpty { Text(Copy.noSales).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            ForEach(document.sales) { value in
                VStack(alignment: .leading, spacing: Layout.gap) {
                    Text(value.currency).font(UFitTypography.headline)
                    Text(value.ordersLabel).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                    figure(Copy.captured, value.captured)
                    figure(Copy.refunded, value.refunded)
                    if value.hasRefundInProgress { figure(Copy.inProgress, value.inProgress) }
                    Divider()
                    figure(Copy.net, value.net, emphasized: true)
                }.padding(Layout.gap).overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }
            }
        }
    }
    private func commissions(_ values: [UFitWorkspaceCommissionFigure]) -> some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.commissions).font(UFitTypography.title2.weight(.medium))
            if values.isEmpty { Text(Copy.noCommissions).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            ForEach(values) { value in
                VStack(alignment: .leading, spacing: Layout.gap) {
                    Text(value.currency).font(UFitTypography.headline)
                    figure(Copy.original, value.original)
                    figure(Copy.adjustments, value.adjusted)
                    figure(Copy.commissionNet, value.net, emphasized: true)
                    Divider()
                    figure(Copy.estimated, value.estimated)
                    figure(Copy.pending, value.pending)
                    figure(Copy.validated, value.validated)
                    figure(Copy.paid, value.paid)
                    if value.hasPaidAdjustment { figure(Copy.recover, value.paidAdjustment, emphasized: true) }
                }.padding(Layout.gap).overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }
            }
            UFitButton(action: onCommissions) {
                HStack { Text(Copy.ledger); Spacer(); UFitIcon(systemName: Icon.next) }.frame(minHeight: Layout.touch).contentShape(Rectangle())
            }
        }
    }
    private func figure(_ label: String, _ amount: String, emphasized: Bool = false) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Layout.gap) { Text(label).fixedSize(); Spacer(); Text(amount).monospacedDigit().fixedSize() }
            VStack(alignment: .leading, spacing: Layout.small) { Text(label); Text(amount).monospacedDigit() }
        }.font(emphasized ? UFitTypography.body.weight(.semibold) : UFitTypography.subheadline).accessibilityElement(children: .combine)
    }
}
