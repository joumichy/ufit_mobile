import Foundation

enum UFitRevenueContract {
    static let monthDays = 30
    static let quarterDays = 90
    static let yearMonths = 12
    static let weekDays = 7
    static let step = 1
}
enum UFitRevenueScope: String, Decodable { case creator, brand }

enum UFitRevenuePeriod: String, CaseIterable, Decodable, Identifiable {
    case month = "30d", quarter = "90d", year = "12m"
    var id: Self { self }
    var label: String {
        switch self {
        case .month: String(localized: "30 jours")
        case .quarter: String(localized: "90 jours")
        case .year: String(localized: "12 mois")
        }
    }
}
enum UFitRevenueMetric: String, CaseIterable, Identifiable {
    case salesNet, captured, refunded, commissionNet, original, adjusted
    var id: Self { self }
    var label: String {
        switch self {
        case .salesNet: String(localized: "Après retours")
        case .captured: String(localized: "Encaissé")
        case .refunded: String(localized: "Remboursé")
        case .commissionNet: String(localized: "Après ajustements")
        case .original: String(localized: "Générées")
        case .adjusted: String(localized: "Ajustées")
        }
    }
    static let sales: [Self] = [.salesNet, .captured, .refunded]
    static let commissions: [Self] = [.commissionNet, .original, .adjusted]
}
enum UFitRevenueCalendar {
    static let dayLength = 10
    static let locale = Locale(identifier: "fr_CH")
    private static let wireLocale = Locale(identifier: "en_US_POSIX")
    private static let wireFormat = "yyyy-MM-dd"
    private static let firstWeekday = 2
    static let zone = TimeZone(secondsFromGMT: .zero)!
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = zone; value.firstWeekday = firstWeekday
        return value
    }
    static func parse(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = wireLocale; formatter.timeZone = zone
        formatter.calendar = calendar; formatter.dateFormat = wireFormat; formatter.isLenient = false
        guard value.count == dayLength, let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }
    static func label(_ date: Date, monthOnly: Bool = false) -> String {
        var style = Date.FormatStyle.dateTime.locale(locale)
        style.timeZone = zone
        return monthOnly ? date.formatted(style.month(.abbreviated).year()) : date.formatted(style.day().month(.abbreviated))
    }
}
