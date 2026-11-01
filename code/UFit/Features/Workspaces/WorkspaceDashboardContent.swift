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
        static let validated = String(localized: "Validées")
        static let paid = String(localized: "Payées")
        static let recover = String(localized: "À récupérer sur les commissions payées")
        static let ledger = String(localized: "Historique des commissions")
    }
    private enum Layout {
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8
        static let radius: CGFloat = 16; static let touch: CGFloat = 44; static let bottom: CGFloat = 32; static let rootBottom: CGFloat = 110
        static let singleColumn = [GridItem(.flexible(), alignment: .topLeading)]
        static let columns = [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)]
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let next = "chevron.right" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: sectionTitle, onBack: onBack) {
                if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                else { Button(action: onRefresh) { Image(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let message {
                        Text(message).font(.callout).foregroundStyle(Color.ufitMuted).accessibilityAddTraits(.updatesFrequently)
                        Button(Copy.retry, action: onRefresh).frame(minHeight: Layout.touch)
                    }
                    if let document {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(document.name).font(.title.weight(.medium))
                            Text(document.status).font(.subheadline).foregroundStyle(Color.ufitMuted)
                            if let grade = document.grade { Text(grade).font(.subheadline.weight(.medium)) }
                        }
                        if showsActivity { activity(document.activity) }
                        sales(document)
                        if document.kind == .creator { commissions(document.commissions) }
                    } else if isLoading || message == nil { ProgressView(Copy.loading).frame(maxWidth: .infinity) }
                }.padding(Layout.page).padding(.bottom, isPrimarySection ? Layout.rootBottom : Layout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
    private func activity(_ rows: [UFitWorkspaceActivityFigure]) -> some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.activity).font(.title2.weight(.medium))
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? Layout.singleColumn : Layout.columns, spacing: Layout.gap) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(row.value, format: .number).font(.title2.weight(.medium)).monospacedDigit()
                        Text(row.label).font(.subheadline).foregroundStyle(Color.ufitMuted).fixedSize(horizontal: false, vertical: true)
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
                Text(document.kind == .creator ? Copy.attributed : Copy.sales).font(.title2.weight(.medium))
                Text(document.kind == .creator ? Copy.merchandiseBasis : Copy.orderBasis).font(.caption).foregroundStyle(Color.ufitMuted)
            }
            if document.sales.isEmpty { Text(Copy.noSales).font(.callout).foregroundStyle(Color.ufitMuted) }
            ForEach(document.sales) { value in
                VStack(alignment: .leading, spacing: Layout.gap) {
                    Text(value.currency).font(.headline)
                    Text(value.ordersLabel).font(.subheadline).foregroundStyle(Color.ufitMuted)
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
            Text(Copy.commissions).font(.title2.weight(.medium))
            if values.isEmpty { Text(Copy.noCommissions).font(.callout).foregroundStyle(Color.ufitMuted) }
            ForEach(values) { value in
                VStack(alignment: .leading, spacing: Layout.gap) {
                    Text(value.currency).font(.headline)
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
            Button(action: onCommissions) {
                HStack { Text(Copy.ledger); Spacer(); Image(systemName: Icon.next) }.frame(minHeight: Layout.touch).contentShape(Rectangle())
            }
        }
    }
    private func figure(_ label: String, _ amount: String, emphasized: Bool = false) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Layout.gap) { Text(label).fixedSize(); Spacer(); Text(amount).monospacedDigit().fixedSize() }
            VStack(alignment: .leading, spacing: Layout.small) { Text(label); Text(amount).monospacedDigit() }
        }.font(emphasized ? .body.weight(.semibold) : .subheadline).accessibilityElement(children: .combine)
    }
}
