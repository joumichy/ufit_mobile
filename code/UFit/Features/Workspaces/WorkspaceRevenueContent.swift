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
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
            Text(String(localized: "Vos revenus, en perspective")).font(UFitTypography.title2.weight(.medium))
            HStack(spacing: UFitSpace.xs) {
                ForEach(UFitRevenuePeriod.allCases) { choice in
                    UFitButton(action: { period = choice }) { Text(choice.label).frame(maxWidth: .infinity) }
                        .ufitButtonStyle(period == choice ? .primary : .secondary, compact: true)
                        .accessibilityAddTraits(period == choice ? .isSelected : [])
                        .accessibilityHint(String(localized: "Période des revenus"))
                }
            }
            if let message {
                UFitEmptyState(title: String(localized: "Graphiques indisponibles"), message: message, symbol: Icon.chart)
                UFitActionButton(title: String(localized: "Réessayer"), kind: .secondary, action: onRetry)
            } else if isLoading || document == nil {
                UFitLoading(String(localized: "Chargement des revenus")).frame(maxWidth: .infinity, minHeight: Layout.loadingHeight)
            } else if let document {
                Text(range(document)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                if document.currencies.isEmpty {
                    VStack(alignment: .leading, spacing: UFitSpace.sm) {
                        UFitIcon(systemName: Icon.chart).font(UFitTypography.title).accessibilityHidden(true)
                        Text(String(localized: "La suite s’écrit ici")).font(UFitTypography.headline)
                        Text(isCreator ? String(localized: "Aucune vente attribuée ni commission sur cette période. Vos premières ventes donneront vie à ces graphiques.") : String(localized: "Aucune commande encaissée sur cette période. Essayez une période plus longue pour retrouver vos ventes."))
                            .font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    }.padding(UFitSpace.lg).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card))
                }
                ForEach(document.currencies) { currency in
                    VStack(alignment: .leading, spacing: UFitSpace.lg) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(currency.currency).font(UFitTypography.title3.weight(.semibold))
                            Spacer(minLength: UFitSpace.sm)
                            Text(UFitWorkspaceFinancialModeCopy.label(currency.liveMode)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        }
                        if isCreator {
                            UFitWorkspaceRevenueCard(currency: currency, granularity: document.granularity, isCommission: true, metric: $commissionMetric)
                            UFitRevenueCommissionDistribution(currency: currency)
                        }
                        UFitWorkspaceRevenueCard(currency: currency, granularity: document.granularity, isCommission: false, metric: $salesMetric, attributedSales: isCreator)
                    }
                }
                Text(isCreator ? String(localized: "Ventes classées par date de commande ; commissions par date de création. Montants et états après ajustements connus à ce jour. Pièces attribuées, hors livraison et taxes.") : String(localized: "Commandes classées par date de création, parmi celles encaissées. Remboursements connus à ce jour, livraison et taxes incluses. Ce net ne déduit pas les frais Stripe ni les commissions et ne représente pas un versement."))
                    .font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
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
    private enum Layout { static let loadingHeight: CGFloat = 220 }
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
            Text(isCommission ? String(localized: "Commissions générées") : attributedSales ? String(localized: "Ventes attribuées") : String(localized: "Ventes encaissées"))
                .font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
            Text(UFitMoney.format(currency.total(metric), currency: currency.currency)).font(UFitTypography.largeTitle.weight(.medium)).monospacedDigit()
                .minimumScaleFactor(Layout.minimumAmountScale).lineLimit(Layout.amountLineCount).accessibilityLabel("\(metric.label), \(UFitMoney.format(currency.total(metric), currency: currency.currency))")
            if !isCommission {
                Text(String(localized: "Avant frais Stripe et commissions")).font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText)
            }
            ScrollView(.horizontal) {
                HStack(spacing: UFitSpace.xs) {
                    ForEach(metrics) { value in
                        UFitButton(action: { metric = value }) { Text(value.label).font(UFitTypography.caption) }
                            .ufitButtonStyle(value == metric ? .primary : .secondary, compact: true)
                            .accessibilityAddTraits(value == metric ? .isSelected : [])
                    }
                }
            }.scrollIndicators(.hidden)
            UFitRevenueChart(points: currency.points.map { point in
                UFitRevenueChartPoint(id: point.date, label: dateLabel(point.date), value: point.amount(metric), formatted: UFitMoney.format(point.amount(metric), currency: currency.currency))
            }, title: metric.label)
            Text(granularity == .week ? String(localized: "Par semaine · première et dernière semaines partielles") : granularity == .month ? String(localized: "Par mois · mois en cours partiel") : String(localized: "Par jour · journée en cours partielle"))
                .font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText)
        }.padding(UFitSpace.md).background(Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.card))
            .overlay { RoundedRectangle(cornerRadius: UFitRadius.card).stroke(Color.ufitBorder) }
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
            Text(String(localized: "Où en sont ces commissions ?")).font(UFitTypography.headline)
            Text(String(localized: "État actuel des commissions de la période")).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            ForEach(figures) { figure in
                VStack(alignment: .leading, spacing: UFitSpace.xs) {
                    ViewThatFits(in: .horizontal) {
                        HStack { Text(figure.id); Spacer(); Text(UFitMoney.format(figure.value, currency: currency.currency)).monospacedDigit() }
                        VStack(alignment: .leading) { Text(figure.id); Text(UFitMoney.format(figure.value, currency: currency.currency)).monospacedDigit() }
                    }.font(UFitTypography.caption)
                    GeometryReader { geometry in
                        Capsule().fill(Color.ufitBorder)
                        Capsule().fill(Color.ufitInk).frame(width: geometry.size.width * CGFloat(figure.value) / CGFloat(max(UFitRevenueContract.step, figures.map(\.value).max() ?? .zero)))
                    }.frame(height: Layout.bar).accessibilityHidden(true)
                }.accessibilityElement(children: .combine)
            }
            Text(String(localized: "Disponible signifie éligible au versement ; seul « Payées » indique une commission déjà marquée payée."))
                .font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText)
            let recovery = currency.points.reduce(.zero) { $0 + $1.paidAdjustment }
            if recovery > .zero {
                Text(String(localized: "À récupérer sur les commissions payées : \(UFitMoney.format(recovery, currency: currency.currency))"))
                    .font(UFitTypography.caption)
            }
        }.padding(UFitSpace.md).background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card))
    }
    private enum Layout { static let bar: CGFloat = 4 }
}
