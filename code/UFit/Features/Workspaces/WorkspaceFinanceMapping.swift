import Foundation

private enum WorkspaceFinanceCopy {
    static let outfits = String(localized: "Tenues"); static let published = String(localized: "Publiées")
    static let draft = String(localized: "Brouillons"); static let review = String(localized: "En validation")
    static let rejected = String(localized: "À corriger"); static let preparing = String(localized: "En préparation"); static let shipped = String(localized: "Expédiées")
    static let products = String(localized: "Produits"); static let active = String(localized: "En vente")
    static let paid = String(localized: "À préparer"); static let lowStock = String(localized: "Variantes à stock faible")
    static let locale = Locale(identifier: "fr_CH"); static let maximumRateDigits = 2
}
extension UFitWorkspaceDashboardDocument {
    var presentation: UFitWorkspaceDashboardPresentation {
        switch self {
        case .creator(let value):
            let activity = value.performance.outfits
            return .init(name: value.profile.displayName, kind: .creator, status: value.profile.status.label,
                grade: String(localized: "Grade : \(value.profile.grade.label)"), activity: [
                    .init(id: .outfits, label: WorkspaceFinanceCopy.outfits, value: activity.total),
                    .init(id: .published, label: WorkspaceFinanceCopy.published, value: activity.published),
                    .init(id: .draft, label: WorkspaceFinanceCopy.draft, value: activity.draft),
                    .init(id: .review, label: WorkspaceFinanceCopy.review, value: activity.underReview),
                    .init(id: .rejected, label: WorkspaceFinanceCopy.rejected, value: activity.rejected)],
                sales: value.performance.sales.currencies.map(\.presentation), commissions: value.performance.commissions.map(\.presentation))
        case .brand(let value):
            return .init(name: value.profile.brandName, kind: .brand, status: value.profile.status.label, grade: nil, activity: [
                .init(id: .products, label: WorkspaceFinanceCopy.products, value: value.performance.products.total),
                .init(id: .active, label: WorkspaceFinanceCopy.active, value: value.performance.products.active),
                .init(id: .review, label: WorkspaceFinanceCopy.review, value: value.performance.products.underReview),
                .init(id: .rejected, label: WorkspaceFinanceCopy.rejected, value: value.performance.products.rejected),
                .init(id: .paid, label: WorkspaceFinanceCopy.paid, value: value.performance.orders.paid),
                .init(id: .preparing, label: WorkspaceFinanceCopy.preparing, value: value.performance.orders.preparing),
                .init(id: .shipped, label: WorkspaceFinanceCopy.shipped, value: value.performance.orders.shipped),
                .init(id: .lowStock, label: WorkspaceFinanceCopy.lowStock, value: value.performance.stock.lowStockVariants)],
                sales: value.performance.sales.currencies.map(\.presentation), commissions: [])
        }
    }
}
private extension UFitWorkspaceSalesCurrencyDTO {
    var presentation: UFitWorkspaceSalesFigure {
        .init(currency: currency, orderCount: capturedOrderCount, captured: UFitMoney.format(capturedAmount, currency: currency),
            refunded: UFitMoney.format(refundedAmount, currency: currency), inProgress: UFitMoney.format(refundInProgressAmount, currency: currency),
            net: UFitMoney.format(netAmount, currency: currency), hasRefundInProgress: refundInProgressAmount > .zero)
    }
}
private extension UFitWorkspaceCommissionCurrencyDTO {
    var presentation: UFitWorkspaceCommissionFigure {
        .init(currency: currency, original: UFitMoney.format(originalAmount, currency: currency), adjusted: UFitMoney.format(adjustedAmount, currency: currency),
            net: UFitMoney.format(netAmount, currency: currency), estimated: UFitMoney.format(estimatedAmount, currency: currency),
            pending: UFitMoney.format(pendingAmount, currency: currency), validated: UFitMoney.format(validatedAmount, currency: currency),
            paid: UFitMoney.format(paidAmount, currency: currency), paidAdjustment: UFitMoney.format(paidAdjustmentAmount, currency: currency),
            hasPaidAdjustment: paidAdjustmentAmount > .zero)
    }
}
extension UFitWorkspaceCommissionDTO {
    func presentation() throws -> UFitWorkspaceCommissionEntry {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent; formatter.locale = WorkspaceFinanceCopy.locale
        formatter.maximumFractionDigits = WorkspaceFinanceCopy.maximumRateDigits
        let decimal = NSDecimalNumber(decimal: Decimal(rateBps) / Decimal(UFitWorkspaceFinanceContract.basisPoints))
        guard let rate = formatter.string(from: decimal) else { throw UFitWorkspaceFinanceFailure.document }
        return .init(id: id, date: createdAt.label, state: status, releaseSummary: try release.summary(), releaseDate: release.detailDate,
            currency: currency, base: UFitMoney.format(baseAmount, currency: currency), rate: rate,
            original: UFitMoney.format(originalAmount, currency: currency), adjusted: UFitMoney.format(adjustedAmount, currency: currency),
            net: UFitMoney.format(netAmount, currency: currency), paidAdjustment: UFitMoney.format(paidAdjustmentAmount, currency: currency), hasPaidAdjustment: paidAdjustmentAmount > .zero)
    }
}
