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
    static let singleOccurrence = 1
    private static let boundarySecond: TimeInterval = 1
    private static let universalZone = TimeZone(secondsFromGMT: .zero)!
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
    static func occurrences(on day: Date, hour: Int, minute: Int, zone: TimeZone) -> [Date] {
        let calendar = calendar(zone: zone)
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return [] }
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour; parts.minute = minute; parts.second = .zero
        guard let wallTime = self.calendar(zone: universalZone).date(from: parts) else { return [] }
        // Use the day's actual offsets: a repeated interval need not last one hour.
        var offsets = Set([interval.start, interval.end.addingTimeInterval(-boundarySecond)].map { zone.secondsFromGMT(for: $0) })
        var cursor = interval.start.addingTimeInterval(-boundarySecond)
        while let transition = zone.nextDaylightSavingTimeTransition(after: cursor), transition < interval.end {
            offsets.insert(zone.secondsFromGMT(for: transition))
            cursor = transition.addingTimeInterval(boundarySecond)
        }
        return offsets.map { wallTime.addingTimeInterval(-TimeInterval($0)) }.filter { value in
            calendar.isDate(value, inSameDayAs: day) && calendar.component(.hour, from: value) == hour
                && calendar.component(.minute, from: value) == minute
        }.sorted()
    }
}
