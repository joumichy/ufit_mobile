import Foundation

struct UFitCurrency: Codable, Hashable, Identifiable {
    let code: String
    let minorUnitDigits: Int
    var id: String { code }
}
