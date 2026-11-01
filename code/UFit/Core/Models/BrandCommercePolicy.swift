import Foundation

struct UFitBrandCommercePolicy: Codable, Equatable {
    struct Rate: Codable, Equatable {
        let country: String
        let currency: String
        let amount: Int
        let taxBasisPoints: Int
        let taxOnShipping: Bool
    }
    let returnWindowDays: Int
    let returnPolicy: String
    let pricesIncludeTaxes: Bool
    let taxNotice: String
    let customsNotice: String
    let shippingRates: [Rate]
}
enum UFitBrandCommerceInput {
    static let unconfiguredVersion = 0; static let versionStep = 1
    static let maximumVersion = UFitDecimalInput.maximumInteger
    static let taxFractionDigits = 2; static let maximumBasisPoints = 10000
    static let separator = " · "; static let space = " "
    static func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
}
struct UFitBrandShippingRateKey: Hashable { let country: String; let currency: String }
struct UFitBrandShippingRateDraft: Identifiable, Equatable {
    let id: UUID
    var country = String(); var currency = String(); var amount = String(); var taxPercent = String()
    var taxOnShipping: Bool?
    init(id: UUID = UUID()) { self.id = id }
    var destination: UFitBrandShippingRateKey { .init(country: country, currency: currency) }
}
struct UFitBrandCommerceDraft: Equatable {
    var returnWindowDays = String(); var returnPolicy = String(); var pricesIncludeTaxes: Bool?
    var taxNotice = String(); var customsNotice = String()
    var rates: [UFitBrandShippingRateDraft] = []
    init() {}
    init(policy: UFitBrandCommercePolicy, currencies: [UFitCurrency]) throws {
        returnWindowDays = String(policy.returnWindowDays); returnPolicy = policy.returnPolicy; pricesIncludeTaxes = policy.pricesIncludeTaxes
        taxNotice = policy.taxNotice; customsNotice = policy.customsNotice
        rates = try policy.shippingRates.map { rate in
            guard let currency = currencies.first(where: { $0.code == rate.currency }) else { throw UFitBrandCommerceDraftError.invalid }
            var value = UFitBrandShippingRateDraft()
            value.country = rate.country; value.currency = rate.currency
            value.amount = UFitDecimalInput.text(rate.amount, fractionalDigits: currency.minorUnitDigits)
            value.taxPercent = UFitDecimalInput.text(rate.taxBasisPoints, fractionalDigits: UFitBrandCommerceInput.taxFractionDigits)
            value.taxOnShipping = rate.taxOnShipping
            return value
        }
    }
    func policy(countries: [UFitCountry], currencies: [UFitCurrency]) throws -> UFitBrandCommercePolicy {
        guard UFitBrandCommerceValidation.policy(self, countries: countries, currencies: currencies).isEmpty,
              let days = UFitDecimalInput.integer(returnWindowDays), let includeTaxes = pricesIncludeTaxes else { throw UFitBrandCommerceDraftError.invalid }
        let shippingRates = try rates.map { rate -> UFitBrandCommercePolicy.Rate in
            guard let currency = currencies.first(where: { $0.code == rate.currency }),
                  let amount = UFitDecimalInput.scaledAmount(rate.amount, fractionalDigits: currency.minorUnitDigits) else { throw UFitBrandCommerceDraftError.invalid }
            let basisPoints: Int
            let taxShipping: Bool
            if includeTaxes { basisPoints = .zero; taxShipping = false }
            else {
                guard let tax = UFitDecimalInput.scaledAmount(rate.taxPercent, fractionalDigits: UFitBrandCommerceInput.taxFractionDigits, maximum: UFitBrandCommerceInput.maximumBasisPoints),
                      let onShipping = rate.taxOnShipping else { throw UFitBrandCommerceDraftError.invalid }
                basisPoints = tax; taxShipping = onShipping
            }
            return .init(country: rate.country, currency: rate.currency, amount: amount, taxBasisPoints: basisPoints, taxOnShipping: taxShipping)
        }
        return .init(returnWindowDays: days, returnPolicy: UFitBrandCommerceInput.trimmed(returnPolicy), pricesIncludeTaxes: includeTaxes,
            taxNotice: UFitBrandCommerceInput.trimmed(taxNotice), customsNotice: UFitBrandCommerceInput.trimmed(customsNotice), shippingRates: shippingRates)
    }
}
enum UFitBrandCommerceField: Hashable { case returnWindowDays, returnPolicy, pricesIncludeTaxes, taxNotice, customsNotice, destinations }
enum UFitBrandShippingRateField: Hashable { case country, currency, amount, taxPercent, taxOnShipping }
enum UFitBrandCommerceDraftError: LocalizedError {
    case invalid
    var errorDescription: String? { String(localized: "Vérifiez les conditions et les tarifs avant l’enregistrement.") }
}
enum UFitBrandCommerceValidation {
    static func rate(_ draft: UFitBrandShippingRateDraft, pricesIncludeTaxes: Bool?, countries: [UFitCountry], currencies: [UFitCurrency], others: [UFitBrandShippingRateDraft]) -> [UFitBrandShippingRateField: String] {
        var errors: [UFitBrandShippingRateField: String] = [:]
        if !countries.contains(where: { $0.id == draft.country }) { errors[.country] = Copy.country }
        if let currency = currencies.first(where: { $0.code == draft.currency }) {
            if UFitDecimalInput.scaledAmount(draft.amount, fractionalDigits: currency.minorUnitDigits) == nil {
                errors[.amount] = String(localized: "Saisissez un montant positif ou nul, avec au plus \(currency.minorUnitDigits) décimale(s).")
            }
        } else { errors[.currency] = Copy.currency }
        if pricesIncludeTaxes != true {
            if UFitDecimalInput.scaledAmount(draft.taxPercent, fractionalDigits: UFitBrandCommerceInput.taxFractionDigits, maximum: UFitBrandCommerceInput.maximumBasisPoints) == nil { errors[.taxPercent] = Copy.taxPercent }
            if draft.taxOnShipping == nil { errors[.taxOnShipping] = Copy.choice }
        }
        if errors[.country] == nil && errors[.currency] == nil && others.contains(where: { $0.id != draft.id && $0.destination == draft.destination }) { errors[.country] = Copy.duplicate }
        return errors
    }
    static func policy(_ draft: UFitBrandCommerceDraft, countries: [UFitCountry], currencies: [UFitCurrency]) -> [UFitBrandCommerceField: String] {
        var errors: [UFitBrandCommerceField: String] = [:]
        if UFitDecimalInput.integer(draft.returnWindowDays) == nil { errors[.returnWindowDays] = Copy.days }
        if UFitBrandCommerceInput.trimmed(draft.returnPolicy).isEmpty { errors[.returnPolicy] = Copy.returnPolicy }
        if draft.pricesIncludeTaxes == nil { errors[.pricesIncludeTaxes] = Copy.choice }
        if UFitBrandCommerceInput.trimmed(draft.taxNotice).isEmpty { errors[.taxNotice] = Copy.taxNotice }
        if UFitBrandCommerceInput.trimmed(draft.customsNotice).isEmpty { errors[.customsNotice] = Copy.customsNotice }
        if draft.rates.isEmpty { errors[.destinations] = Copy.destination }
        else if draft.rates.contains(where: { !rate($0, pricesIncludeTaxes: draft.pricesIncludeTaxes, countries: countries, currencies: currencies, others: draft.rates).isEmpty }) { errors[.destinations] = Copy.rates }
        return errors
    }
    private enum Copy {
        static let country = String(localized: "Choisissez un pays disponible."); static let currency = String(localized: "Choisissez une devise disponible.")
        static let taxPercent = String(localized: "Saisissez un taux de 0 à 100 %, avec au plus deux décimales.")
        static let choice = String(localized: "Choisissez Oui ou Non.")
        static let duplicate = String(localized: "Un tarif existe déjà pour ce pays et cette devise.")
        static let days = String(localized: "Saisissez un nombre entier de jours positif ou nul.")
        static let returnPolicy = String(localized: "Précisez les conditions de retour.")
        static let taxNotice = String(localized: "Précisez les informations fiscales affichées avant achat.")
        static let customsNotice = String(localized: "Précisez les informations douanières affichées avant achat.")
        static let destination = String(localized: "Ajoutez au moins une destination et son tarif.")
        static let rates = String(localized: "Vérifiez les destinations et leurs tarifs.")
    }
}
