import Foundation

enum UFitMoney {
    private static let locale = Locale(identifier: "fr_CH")
    private static let decimalBase = Decimal(10)
    static func format(_ amount: Int, currency: String) -> String {
        guard let digits = UFitCurrencyMinorUnits.digits(for: currency) else {
            return String(localized: "Montant indisponible")
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        var divisor = Decimal(1)
        for _ in 0..<digits { divisor *= decimalBase }
        let major = NSDecimalNumber(decimal: Decimal(amount) / divisor)
        return formatter.string(from: major) ?? major.stringValue + currency
    }
}
