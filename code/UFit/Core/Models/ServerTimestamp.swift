import Foundation

struct UFitTimestamp: Decodable, Equatable {
    let value: Date
    init(value: Date) { self.value = value }
    init?(isoString: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let value = formatter.date(from: isoString) else { return nil }
        self.value = value
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let timestamp = Self(isoString: text) else { throw DecodingError.dataCorruptedError(in: container, debugDescription: Wire.invalid) }
        self = timestamp
    }
    var label: String { value.formatted(.dateTime.day().month(.wide).year().locale(Wire.locale)) }
    private enum Wire { static let invalid = "Invalid server timestamp"; static let locale = Locale(identifier: "fr_CH") }
}
