import Foundation

enum UFitMoney {
    private static let locale = Locale(identifier: "fr_CH")
    private static let decimalBase = Decimal(10)
    static func format(_ amount: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency
        var divisor = Decimal(1)
        for _ in 0..<formatter.maximumFractionDigits { divisor *= decimalBase }
        let major = NSDecimalNumber(decimal: Decimal(amount) / divisor)
        return formatter.string(from: major) ?? major.stringValue + currency
    }
}
