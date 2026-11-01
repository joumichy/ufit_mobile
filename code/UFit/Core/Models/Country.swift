import Foundation

struct UFitCountry: Identifiable {
    let id: String; let name: String
    static let codePattern = #"^[A-Z]{2}$"#
}
