import Foundation

enum UFitPublicationFormatting {
    static let locale = Locale(identifier: "fr_CH")
    enum Template: String { case month = "MMMM y", day = "EEEE d MMMM y", time = "d MMM y HH:mm zzz" }
    static func text(_ date: Date, template: Template, zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale; formatter.timeZone = zone
        formatter.setLocalizedDateFormatFromTemplate(template.rawValue)
        return formatter.string(from: date)
    }
}

enum UFitPublicationCalendarMath {
    static let initialDelay: TimeInterval = 3_600
    static let hourCount = 24
    static let minuteCount = 60
    static let minuteStep = 1
    static let nextMonth = 1
    static let twoDigit = "%02d"
    static let timeDigits = 2
    static let decimalBase = 10
    static func calendar(zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone; calendar.locale = UFitPublicationFormatting.locale
        return calendar
    }
    static func minuteLabel(_ value: Int) -> String { String(format: twoDigit, value) }
    static func timeValue(_ text: String, upperBound: Int) -> Int? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.count <= timeDigits else { return nil }
        let digits = input.compactMap(\.wholeNumberValue)
        guard digits.count == input.count, digits.allSatisfy({ $0 < decimalBase }) else { return nil }
        guard let value = Int(digits.map(String.init).joined()), value < upperBound else { return nil }
        return value
    }
}
