import SwiftUI

struct UFitWorkspaceRevenueContent: View {
    let document: UFitWorkspaceRevenueDTO?
    @Binding var period: UFitRevenuePeriod
    let isLoading: Bool
    let message: String?
    let isCreator: Bool
    let onRetry: () -> Void
    @State private var salesMetric: UFitRevenueMetric = .salesNet
    @State private var commissionMetric: UFitRevenueMetric = .commissionNet
    @State private var selectedGroup: UFitWorkspaceFinancialGroup?
    @State private var showsAttributedSales = false
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
            HStack(spacing: UFitSpace.xs) {
                ForEach(UFitRevenuePeriod.allCases) { choice in
                    UFitButton(action: { period = choice }) { Text(choice.label).frame(maxWidth: .infinity) }
                        .ufitButtonStyle(period == choice ? .primary : .secondary, compact: true)
                        .accessibilityAddTraits(period == choice ? .isSelected : [])
                        .accessibilityHint(String(localized: "Période des revenus"))
                }
            }
            if let message {
                UFitEmptyState(title: Copy.unavailable, message: message, symbol: Icon.chart)
                UFitActionButton(title: String(localized: "Réessayer"), kind: .secondary, action: onRetry)
            } else if isLoading || document == nil {
                UFitLoading(String(localized: "Chargement des revenus")).frame(maxWidth: .infinity, minHeight: Layout.loadingHeight)
            } else if let document {
                Text(range(document)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                if document.currencies.isEmpty {
                    VStack(alignment: .leading, spacing: UFitSpace.sm) {
                        UFitIcon(systemName: Icon.chart).font(UFitTypography.title).accessibilityHidden(true)
                        Text(Copy.emptyTitle).font(UFitTypography.headline)
                        Text(isCreator ? Copy.creatorEmpty : Copy.brandEmpty)
                            .font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    }.padding(UFitSpace.lg).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card))
                }
                if let currency = document.currencies.first(where: { $0.id == selectedGroup }) ?? document.currencies.first {
                    if document.currencies.count > Layout.singleGroup {
                        UFitChoiceBar(title: Copy.context, selection: Binding(get: { currency.id }, set: { selectedGroup = $0 }),
                            options: document.currencies.map { .init(value: $0.id, title: UFitWorkspaceFinancialModeCopy.context(currency: $0.currency, liveMode: $0.liveMode)) })
                    }
                    if isCreator {
                        UFitChoiceBar(title: Copy.analysis, selection: $showsAttributedSales,
                            options: [.init(value: false, title: Copy.commissions), .init(value: true, title: Copy.attributedSales)])
                    }
                    UFitWorkspaceRevenueCard(currency: currency, granularity: document.granularity,
                        isCommission: isCreator && !showsAttributedSales,
                        metric: isCreator && !showsAttributedSales ? $commissionMetric : $salesMetric, attributedSales: isCreator)
                        .id(currency.id)
                    if currency.liveMode == nil {
                        Text(UFitWorkspaceFinancialModeCopy.unclassified).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    }
                    if isCreator && !showsAttributedSales {
                        UFitDisclosure(Copy.commissionStates) { UFitRevenueCommissionDistribution(currency: currency) }
                            .id(currency.id)
                    }
                }
                UFitDisclosure(Copy.calculation) {
                    Text(isCreator ? Copy.creatorBasis : Copy.brandBasis)
                        .font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                }
                Text(String(localized: "Jours UTC · Actualisé le \(document.asOf.value.formatted(.dateTime.day().month().hour().minute()))"))
                    .font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText)
            }
        }
    }
    private func range(_ value: UFitWorkspaceRevenueDTO) -> String {
        guard let start = UFitRevenueCalendar.parse(value.start), let end = UFitRevenueCalendar.parse(value.end),
              let last = UFitRevenueCalendar.calendar.date(byAdding: .day, value: -UFitRevenueContract.step, to: end) else { return String() }
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated).year().locale(UFitRevenueCalendar.locale)
        style.timeZone = UFitRevenueCalendar.zone
        return "\(start.formatted(style)) – \(last.formatted(style))"
    }
    private enum Copy {
        static let unavailable = String(localized: "Analyse indisponible")
        static let emptyTitle = String(localized: "Aucun revenu sur cette période")
        static let creatorEmpty = String(localized: "Aucune vente attribuée ni commission. Essayez une période plus longue.")
        static let brandEmpty = String(localized: "Aucune commande encaissée. Essayez une période plus longue.")
        static let context = String(localized: "Devise et mode")
        static let analysis = String(localized: "Analyse")
        static let commissions = String(localized: "Commissions")
        static let attributedSales = String(localized: "Ventes attribuées")
        static let commissionStates = String(localized: "État des commissions de cette période")
        static let calculation = String(localized: "Comprendre les montants")
        static let creatorBasis = String(localized: "Ventes classées par date de commande ; commissions par date de création. Montants et états après ajustements connus à ce jour. Pièces attribuées, hors livraison et taxes.")
        static let brandBasis = String(localized: "Commandes classées par date de création, parmi celles encaissées. Remboursements connus à ce jour, livraison et taxes incluses. Ce net ne déduit pas les frais Stripe ni les commissions et ne représente pas un versement.")
    }
    private enum Layout { static let loadingHeight: CGFloat = 220; static let singleGroup = 1 }
    private enum Icon { static let chart = "chart.xyaxis.line" }
}

private struct UFitWorkspaceRevenueCard: View {
    let currency: UFitRevenueCurrencyDTO
    let granularity: UFitWorkspaceRevenueDTO.Granularity
    let isCommission: Bool
    @Binding var metric: UFitRevenueMetric
    var attributedSales = false
    private var metrics: [UFitRevenueMetric] { isCommission ? UFitRevenueMetric.commissions : UFitRevenueMetric.sales }
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { Text(heading); Spacer(); Text(UFitWorkspaceFinancialModeCopy.label(currency.liveMode)) }
                VStack(alignment: .leading, spacing: UFitSpace.xs) { Text(heading); Text(UFitWorkspaceFinancialModeCopy.label(currency.liveMode)) }
            }.font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            Text(UFitMoney.format(currency.total(metric), currency: currency.currency)).font(UFitTypography.largeTitle.weight(.medium)).monospacedDigit()
                .minimumScaleFactor(Layout.minimumAmountScale).lineLimit(Layout.amountLineCount)
                .accessibilityLabel(UFitWorkspaceFinancialModeCopy.amountContext(metric.label, amount: UFitMoney.format(currency.total(metric), currency: currency.currency), liveMode: currency.liveMode))
            if !isCommission && attributedSales { Text(Copy.merchandiseBasis).font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText) }
            if !isCommission && !attributedSales {
                Text(String(localized: "Avant frais Stripe et commissions")).font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText)
            }
            ScrollView(.horizontal) {
                HStack(spacing: UFitSpace.xs) {
                    ForEach(metrics) { value in
                        UFitButton(action: { metric = value }) { Text(value.label).font(UFitTypography.caption) }
                            .ufitButtonStyle(value == metric ? .primary : .secondary, compact: true)
                            .accessibilityAddTraits(value == metric ? .isSelected : [])
                            .accessibilityLabel(UFitWorkspaceFinancialModeCopy.namedContext(value.label, currency: currency.currency, liveMode: currency.liveMode))
                    }
                }
            }.scrollIndicators(.hidden)
            if currency.points.contains(where: { $0.amount(metric) > .zero }) {
                UFitRevenueChart(points: currency.points.map { point in
                    UFitRevenueChartPoint(id: point.date, label: dateLabel(point.date), value: point.amount(metric), formatted: UFitMoney.format(point.amount(metric), currency: currency.currency))
                }, title: UFitWorkspaceFinancialModeCopy.namedContext(metric.label, currency: currency.currency, liveMode: currency.liveMode))
                Text(granularity == .week ? String(localized: "Par semaine · première et dernière semaines partielles") : granularity == .month ? String(localized: "Par mois · mois en cours partiel") : String(localized: "Par jour · journée en cours partielle"))
                    .font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText)
            } else {
                Text(Copy.noAmount)
                    .font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).padding(.vertical, UFitSpace.lg)
            }
        }.padding(UFitSpace.md).background(Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.card))
            .overlay { RoundedRectangle(cornerRadius: UFitRadius.card).stroke(Color.ufitBorder) }
    }
    private var heading: String { isCommission ? Copy.commissions : attributedSales ? Copy.attributed : Copy.sales }
    private enum Copy {
        static let commissions = String(localized: "Commissions")
        static let attributed = String(localized: "Ventes attribuées")
        static let sales = String(localized: "Ventes")
        static let noAmount = String(localized: "Aucun montant pour cette mesure sur la période.")
        static let merchandiseBasis = String(localized: "Pièces attribuées, hors livraison et taxes")
    }
    private func dateLabel(_ text: String) -> String {
        guard let date = UFitRevenueCalendar.parse(text) else { return text }
        let label = UFitRevenueCalendar.label(date, monthOnly: granularity == .month)
        return granularity == .week ? String(localized: "Sem. du \(label)") : label
    }
    private enum Layout { static let minimumAmountScale = 0.6; static let amountLineCount = 1 }
}

private struct UFitRevenueCommissionDistribution: View {
    let currency: UFitRevenueCurrencyDTO
    private struct Figure: Identifiable { let id: String; let value: Int }
    private var figures: [Figure] {
        [.init(id: String(localized: "Estimées"), value: currency.points.reduce(.zero) { $0 + $1.estimated }),
         .init(id: String(localized: "En attente"), value: currency.points.reduce(.zero) { $0 + $1.pending }),
         .init(id: String(localized: "Disponibles pour versement"), value: currency.points.reduce(.zero) { $0 + $1.available }),
         .init(id: String(localized: "Payées"), value: currency.points.reduce(.zero) { $0 + $1.paid })]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            Text(String(localized: "État actuel · \(UFitWorkspaceFinancialModeCopy.context(currency: currency.currency, liveMode: currency.liveMode))"))
                .font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            ForEach(figures) { figure in
                VStack(alignment: .leading, spacing: UFitSpace.xs) {
                    ViewThatFits(in: .horizontal) {
                        HStack { Text(figure.id); Spacer(); Text(UFitMoney.format(figure.value, currency: currency.currency)).monospacedDigit() }
                        VStack(alignment: .leading) { Text(figure.id); Text(UFitMoney.format(figure.value, currency: currency.currency)).monospacedDigit() }
                    }.font(UFitTypography.caption)
                }.accessibilityElement(children: .combine)
                    .accessibilityLabel(UFitWorkspaceFinancialModeCopy.amountContext(figure.id, amount: UFitMoney.format(figure.value, currency: currency.currency), liveMode: currency.liveMode))
            }
            Text(String(localized: "Disponible signifie éligible au versement ; seul « Payées » indique une commission déjà marquée payée."))
                .font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText)
            let recovery = currency.points.reduce(.zero) { $0 + $1.paidAdjustment }
            if recovery > .zero {
                Text(String(localized: "À récupérer sur les commissions payées : \(UFitMoney.format(recovery, currency: currency.currency))"))
                    .font(UFitTypography.caption)
                    .accessibilityLabel(UFitWorkspaceFinancialModeCopy.amountContext(String(localized: "À récupérer sur les commissions payées"), amount: UFitMoney.format(recovery, currency: currency.currency), liveMode: currency.liveMode))
            }
        }.padding(UFitSpace.md).background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card))
    }
}
