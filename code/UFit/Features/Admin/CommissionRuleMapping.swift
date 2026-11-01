import Foundation

enum UFitCommissionRuleInput {
    static let percentageDigits = 2
    private enum Copy {
        static let brand = String(localized: "Choisissez une marque.")
        static let rate = String(localized: "Saisissez un taux entre 0 et 100 %, avec deux décimales au maximum.")
        static let reason = String(localized: "Ajoutez un motif de 1 à 500 caractères.")
    }
    static func rate(_ text: String) -> Int? {
        UFitDecimalInput.scaledAmount(text, fractionalDigits: percentageDigits, maximum: UFitCommissionRuleContract.basisPoints)
    }
    static func errors(_ draft: UFitCommissionRuleDraft) -> [UFitCommissionRuleField: String] {
        var result: [UFitCommissionRuleField: String] = [:]
        if draft.brand == nil { result[.brand] = Copy.brand }
        if rate(draft.baseRate) == nil { result[.baseRate] = Copy.rate }
        if rate(draft.bonusRate) == nil { result[.bonusRate] = Copy.rate }
        if !UFitServerTextInput.trimmed(draft.maximumRate).isEmpty && rate(draft.maximumRate) == nil { result[.maximumRate] = Copy.rate }
        if !UFitServerTextInput.valid(draft.reason, maximum: UFitCommissionRuleContract.reasonLimit) { result[.reason] = Copy.reason }
        return result
    }
    static func configuration(_ draft: UFitCommissionRuleDraft) throws -> UFitCommissionRuleConfiguration {
        guard errors(draft).isEmpty, let base = rate(draft.baseRate), let bonus = rate(draft.bonusRate) else { throw UFitCommissionRuleFailure.input }
        let value = UFitCommissionRuleConfiguration(baseRateBps: base, bonusRateBps: bonus, maxRateBps: rate(draft.maximumRate), active: draft.active, reason: UFitServerTextInput.trimmed(draft.reason))
        try value.validate(); return value
    }
}
extension UFitCommissionRuleDTO {
    var editingDraft: UFitCommissionRuleDraft {
        .init(brand: .init(id: brandId, title: brandName, detail: nil),
            product: productId.map { .init(id: $0, title: productName!, detail: nil) },
            grade: creatorGradeCode.map { .init(id: $0, title: creatorGradeLabel!, detail: nil) },
            baseRate: UFitDecimalInput.text(baseRateBps, fractionalDigits: UFitCommissionRuleInput.percentageDigits),
            bonusRate: UFitDecimalInput.text(bonusRateBps, fractionalDigits: UFitCommissionRuleInput.percentageDigits),
            maximumRate: maxRateBps.map { UFitDecimalInput.text($0, fractionalDigits: UFitCommissionRuleInput.percentageDigits) } ?? String(),
            active: active, reason: String())
    }
    func row() throws -> UFitCommissionRuleRow {
        .init(id: scopeId, brand: brandName, product: productName, grade: creatorGradeLabel, rate: try formattedRate(rateBps), revision: revision, active: active)
    }
    func document() throws -> UFitCommissionRuleDocument {
        .init(rule: try row(), baseRate: try formattedRate(baseRateBps), bonusRate: try formattedRate(bonusRateBps),
            maximumRate: try maxRateBps.map(formattedRate))
    }
    func historyRow(currentID: String) throws -> UFitCommissionRevisionRow {
        .init(id: id, revision: revision, rate: try formattedRate(rateBps), date: createdAt.value.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(RateFormat.locale)), reason: reason, active: active, isCurrent: id == currentID)
    }
    private func formattedRate(_ bps: Int) throws -> String {
        let formatter = NumberFormatter(); formatter.numberStyle = .percent; formatter.locale = RateFormat.locale
        formatter.maximumFractionDigits = UFitCommissionRuleInput.percentageDigits
        guard let value = formatter.string(from: NSDecimalNumber(decimal: Decimal(bps) / Decimal(UFitCommissionRuleContract.basisPoints))) else { throw UFitCommissionRuleFailure.document }
        return value
    }
    private enum RateFormat { static let locale = Locale(identifier: "fr_CH") }
}
enum UFitCommissionAdminFailure {
    private enum Status { static let unauthorized = 401; static let forbidden = 403; static let conflict = 409 }
    private enum Copy {
        static let changed = String(localized: "Cette règle a changé. Actualisez sa référence avant de réessayer. Votre saisie est conservée.")
        static let exists = String(localized: "Une règle existe déjà pour cette sélection. Revenez aux règles pour la modifier.")
    }
    static func revoked(_ error: Error) -> Bool {
        guard case UFitAPIError.requestFailed(let status, _, _) = error else { return false }
        return status == Status.unauthorized || status == Status.forbidden
    }
    static func message(_ error: Error, isNew: Bool = false) -> String {
        if case UFitAPIError.requestFailed(let status, _, _) = error, status == Status.conflict { return isNew ? Copy.exists : Copy.changed }
        return error.localizedDescription
    }
}
