import Foundation

enum UFitServerTextInput {
    static let minimumText = 1
    static func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func valid(_ value: String, maximum: Int) -> Bool { (minimumText...maximum).contains(trimmed(value).utf16.count) }
}
