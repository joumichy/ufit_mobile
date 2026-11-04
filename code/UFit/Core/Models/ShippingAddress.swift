import Foundation

struct UFitShippingAddress: Codable, Equatable {
    var fullName = String()
    var line1 = String()
    var line2: String?
    var postalCode = String()
    var city = String()
    var country = Limits.initialCountry
    var phone: String?
    private enum Limits {
        static let initialCountry = "CH"
        static let name = 160, street = 200, postal = 32, city = 120, phone = 40
    }
    var normalized: Self {
        var value = self
        value.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        value.line1 = line1.trimmingCharacters(in: .whitespacesAndNewlines)
        value.postalCode = postalCode.trimmingCharacters(in: .whitespacesAndNewlines)
        value.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        value.line2 = line2?.trimmingCharacters(in: .whitespacesAndNewlines)
        value.phone = phone?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value
    }
    func validate() throws {
        let required = [(fullName, Limits.name), (line1, Limits.street), (postalCode, Limits.postal), (city, Limits.city)]
        guard normalized == self, required.allSatisfy({ !$0.0.isEmpty && $0.0.utf16.count <= $0.1 }),
              (line2?.utf16.count ?? .zero) <= Limits.street, (phone?.utf16.count ?? .zero) <= Limits.phone,
              country.range(of: UFitCountry.codePattern, options: .regularExpression) != nil else {
            throw UFitShippingAddressFailure.fields
        }
    }
}

enum UFitShippingAddressFailure: LocalizedError {
    case document, fields, storage
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "Le carnet d’adresses n’a pas pu être vérifié. Réessayez.")
        case .fields: String(localized: "Vérifiez votre nom, votre adresse et la longueur des champs.")
        case .storage: String(localized: "Le suivi de votre modification ne peut pas être conservé sur cet appareil. Réessayez.")
        }
    }
}
