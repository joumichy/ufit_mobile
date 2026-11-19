import Foundation

enum UFitGenderTarget: String, Codable, CaseIterable, Identifiable {
    case male, female, unisex
    var id: String { rawValue }
    var label: String { switch self { case .male: Copy.male; case .female: Copy.female; case .unisex: Copy.unisex } }
    private enum Copy { static let male = String(localized: "Homme"); static let female = String(localized: "Femme"); static let unisex = String(localized: "Unisexe") }
}
