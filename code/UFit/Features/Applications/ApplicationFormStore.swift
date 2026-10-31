import Foundation
import Observation

@MainActor @Observable
final class UFitApplicationFormStore {
    let kind: UFitApplicationKind
    let correcting: UFitApplicationDocument?
    var values: [UFitApplicationField: String]
    private(set) var errors = [UFitApplicationField: String]()
    private(set) var isBusy = false
    private(set) var message: String?
    private(set) var countries = [UFitApplicationCountry]()
    private(set) var loadingCountries = false
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    private enum Contract { static let locale = Locale(identifier: "fr"); static let country = "CH"; static let secureScheme = "https"; static let at = "@"; static let dot = "."; static let emailParts = 2; static let nameMin = 2; static let creatorNameMax = 80; static let brandNameMax = 120; static let textMin = 20; static let textMax = 2000; static let optionalMin = 5; static let optionalMax = 1000; static let shortMax = 80; static let detailMin = 2 }
    private enum Copy {
        static let required = String(localized: "Ce champ est requis.")
        static let link = String(localized: "Saisissez un lien HTTPS complet.")
        static let email = String(localized: "Saisissez une adresse e-mail valide.")
        static let country = String(localized: "Choisissez votre pays d’établissement.")
        static let length = String(localized: "Respectez la longueur demandée : ")
        static let separator = "–"
        static let characters = String(localized: " caractères.")
        static let invalid = String(localized: "Vérifiez les champs indiqués avant l’envoi.")
    }
    init(kind: UFitApplicationKind, correcting: UFitApplicationDocument?, client: UFitAPIClient, session: UFitSessionStore) {
        self.kind = kind; self.correcting = correcting; self.client = client; self.session = session
        values = correcting?.formValues ?? [.name: session.user?.displayName ?? String(), .email: session.user?.email ?? String(), .country: Contract.country]
    }
    func loadCountries() async {
        guard kind == .brand, !loadingCountries, !isBusy, let userID = session.user?.id else { return }
        loadingCountries = true; message = nil
        defer { loadingCountries = false }
        do {
            let codes = try await client.fetchApplicationCountries()
            guard session.user?.id == userID else { return }
            countries = codes.map { UFitApplicationCountry(id: $0, name: Contract.locale.localizedString(forRegionCode: $0) ?? $0) }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        } catch { if session.user?.id == userID { message = error.localizedDescription } }
    }
    func submit() async -> Bool {
        guard !isBusy, !loadingCountries, let userID = session.user?.id else { return false }
        values = values.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        validate()
        guard errors.isEmpty else { message = Copy.invalid; return false }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            _ = try await client.submitApplication(kind: kind, values: values, correcting: correcting)
            return session.user?.id == userID
        } catch { if session.user?.id == userID { message = error.localizedDescription }; return false }
    }
    private func validate() {
        errors = [:]
        for field in UFitApplicationField.fields(for: kind) {
            let text = values[field] ?? String()
            if text.isEmpty { if !field.isOptional { errors[field] = Copy.required }; continue }
            if field.isLink {
                guard let url = URL(string: text), url.scheme == Contract.secureScheme, let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { errors[field] = Copy.link; continue }
            } else if field == .email {
                let parts = text.split(separator: Contract.at, omittingEmptySubsequences: false)
                if parts.count != Contract.emailParts || parts.contains(where: { $0.isEmpty }) || !parts.last!.contains(Contract.dot) || text.contains(where: { $0.isWhitespace }) { errors[field] = Copy.email }
            } else if field == .country {
                if !countries.contains(where: { $0.id == text }) { errors[field] = Copy.country }
            } else if let range = length(for: field), !range.contains(text.count) { errors[field] = Copy.length + String(range.lowerBound) + Copy.separator + String(range.upperBound) + Copy.characters }
        }
    }
    private func length(for field: UFitApplicationField) -> ClosedRange<Int>? {
        switch field {
        case .name: Contract.nameMin...(kind == .creator ? Contract.creatorNameMax : Contract.brandNameMax)
        case .motivation, .positioning: Contract.textMin...Contract.textMax
        case .audience: Contract.optionalMin...Contract.optionalMax
        case .style, .category: Contract.detailMin...Contract.shortMax
        case .brandsWorn, .priceRange: Contract.detailMin...Contract.optionalMax
        case .shipping, .returns, .commission: Contract.detailMin...Contract.textMax
        default: nil
        }
    }
}
