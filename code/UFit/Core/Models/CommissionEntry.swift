import Foundation

enum UFitCommissionState: String, Decodable {
  case estimated, pending, validated, paid, cancelled
  var label: String {
    switch self {
    case .estimated: Copy.estimated
    case .pending: Copy.pending
    case .validated: Copy.validated
    case .paid: Copy.paid
    case .cancelled: Copy.cancelled
    }
  }
  private enum Copy {
    static let estimated = String(localized: "Estimée")
    static let pending = String(localized: "En attente")
    static let validated = String(localized: "Validée")
    static let paid = String(localized: "Payée")
    static let cancelled = String(localized: "Annulée")
  }
}
struct UFitCommissionEntry: Identifiable {
  let id: String
  let date: String
  let state: UFitCommissionState
  let creatorName: String
  let orderNumber: String
  let productName: String
  let brandName: String
  let quantity: Int
  let releaseSummary: String
  let releaseDate: String?
  let currency: String
  let base: String
  let rate: String
  let original: String
  let adjusted: String
  let net: String
  let paidAdjustment: String
  let hasPaidAdjustment: Bool
}

enum UFitCommissionRateFormat {
  private static let locale = Locale(identifier: "fr_CH")
  private static let maximumDigits = 2
  static func string(_ basisPoints: Int) throws -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.locale = locale
    formatter.maximumFractionDigits = maximumDigits
    let decimal = NSDecimalNumber(
      decimal: Decimal(basisPoints) / Decimal(UFitWorkspaceFinanceContract.basisPoints))
    guard let result = formatter.string(from: decimal) else {
      throw UFitWorkspaceFinanceFailure.document
    }
    return result
  }
}
extension UFitCommissionEntryDTO {
  func presentation() throws -> UFitCommissionEntry {
    let rate = try UFitCommissionRateFormat.string(rateBps)
    return .init(
      id: id, date: createdAt.label, state: status, creatorName: creator.name,
      orderNumber: sale.orderNumber,
      productName: sale.productName, brandName: sale.brandName, quantity: sale.quantity,
      releaseSummary: try release.summary(), releaseDate: release.detailDate,
      currency: currency, base: UFitMoney.format(baseAmount, currency: currency), rate: rate,
      original: UFitMoney.format(originalAmount, currency: currency),
      adjusted: UFitMoney.format(adjustedAmount, currency: currency),
      net: UFitMoney.format(netAmount, currency: currency),
      paidAdjustment: UFitMoney.format(paidAdjustmentAmount, currency: currency),
      hasPaidAdjustment: paidAdjustmentAmount > .zero)
  }
}
