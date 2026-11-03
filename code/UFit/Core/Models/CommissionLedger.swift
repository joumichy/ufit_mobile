import Foundation

enum UFitCommissionLedgerCopy {
  enum Resource { case commissions, relatedReturns }
  static let title = String(localized: "Commissions")
  static let detail = String(localized: "Commission")
  static let search = String(localized: "Pièce, marque, créateur ou vente")
  static let refresh = String(localized: "Actualiser les commissions")
  static let retry = String(localized: "Réessayer")
  static let loading = String(localized: "Chargement des commissions")
  static let detailLoading = String(localized: "Chargement de la commission")
  static let more = String(localized: "Voir les commissions précédentes")
  static let empty = String(localized: "Aucune commission pour le moment")
  static let noMatches = String(localized: "Aucune commission pour ces critères")
  static let reset = String(localized: "Toutes les commissions")
  static let state = String(localized: "Situation")
  static let allStates = String(localized: "Toutes les situations")
  static let currency = String(localized: "Devise")
  static let allCurrencies = String(localized: "Toutes les devises")
  static let order = String(localized: "Voir la commande")
  static let refreshReturns = String(localized: "Actualiser les retours liés")
  static let relatedUnavailable = String(
    localized: "Les retours liés sont indisponibles. Réessayez.")
  static let relatedChanged = String(
    localized: "Les retours liés ont changé. Actualisez pour continuer.")
  static let relatedAccess = String(localized: "Votre accès à ces retours n’est plus disponible.")
  static let returns = String(localized: "Retours liés")
  static let returnsEmpty = String(localized: "Aucun retour lié à cette commission")
  static let returnsLoading = String(localized: "Chargement des retours liés")
  static let moreReturns = String(localized: "Voir les retours précédents")
  static let missing = String(localized: "Cette commission n’est plus disponible")
  static let changed = String(localized: "Les commissions ont changé. Actualisez pour continuer.")
  static let access = String(localized: "Votre accès à ces commissions n’est plus disponible.")
  static let unavailable = String(localized: "Les commissions sont indisponibles. Réessayez.")
  static let offline = String(
    localized: "Connexion indisponible. Vérifiez votre réseau et réessayez.")
  static let verification = String(
    localized: "Les données financières nécessitent une vérification. Réessayez plus tard.")
  static let icon = "banknote"
  static let next = "chevron.right"
  static let refreshIcon = "arrow.clockwise"
  static let searchDebounce = Duration.milliseconds(350)
  private static let locale = Locale(identifier: "fr_CH")
  private enum Status {
    static let unauthorized = 401
    static let forbidden = 403
    static let missing = 404
  }
  static func count(_ value: Int) -> String {
    value == UFitWorkspaceFinanceContract.single
      ? String(localized: "\(value) commission") : String(localized: "\(value) commissions")
  }
  static func asOf(_ value: UFitTimestamp) -> String {
    let date = value.value.formatted(
      .dateTime.day().month(.wide).year().hour().minute().locale(locale))
    return String(localized: "Situation du \(date)")
  }
  static func isRevoked(_ error: Error) -> Bool {
    guard case UFitAPIError.requestFailed(let status, _, _) = error else { return false }
    return status == Status.unauthorized || status == Status.forbidden
  }
  static func isMissing(_ error: Error) -> Bool {
    guard case UFitAPIError.requestFailed(let status, _, _) = error else { return false }
    return status == Status.missing
  }
  static func isChanged(_ error: Error) -> Bool {
    if error is UFitWorkspaceFinanceFailure { return true }
    guard case UFitAPIError.requestFailed(_, _, let code) = error else { return false }
    return code == UFitCommissionLedgerContract.changedCode
  }
  static func message(_ error: Error, resource: Resource = .commissions) -> String {
    if isRevoked(error) { return resource == .commissions ? access : relatedAccess }
    if isChanged(error) { return resource == .commissions ? changed : relatedChanged }
    if case UFitAPIError.requestFailed(_, _, let code) = error,
      code == UFitWorkspaceFinanceContract.persistedCode
    {
      return verification
    }
    if error is URLError { return offline }
    return resource == .commissions ? unavailable : relatedUnavailable
  }
}

struct UFitCommissionRuleSnapshot {
  let base: String
  let bonus: String
  let maximum: String
}
extension UFitCommissionLedgerDetail.Rule {
  func presentation() throws -> UFitCommissionRuleSnapshot {
    let noMaximum = String(localized: "Sans plafond")
    return try .init(
      base: UFitCommissionRateFormat.string(baseRateBps),
      bonus: UFitCommissionRateFormat.string(bonusRateBps),
      maximum: maxRateBps.map(UFitCommissionRateFormat.string) ?? noMaximum)
  }
}
