import Foundation
import Observation

@MainActor @Observable
final class UFitBrandCommercePolicyStore {
    let brandID: String
    let brandName: String
    var draft = UFitBrandCommerceDraft() { didSet { if draft != oldValue && !isSaving { errors = [:]; message = nil } } }
    private(set) var countries: [UFitCountry] = []
    private(set) var currencies: [UFitCurrency] = []
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var message: String?
    private(set) var errors: [UFitBrandCommerceField: String] = [:]
    @ObservationIgnored private var document: UFitManagedBrandCommercePolicy?
    @ObservationIgnored private var baseline = UFitBrandCommerceDraft()
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let userID: String
    private enum Copy {
        static let saved = String(localized: "Conditions enregistrées.")
        static let invalid = String(localized: "Corrigez les champs indiqués avant l’enregistrement.")
    }
    init(space: UFitWorkspaceReference, session: UFitSessionStore) throws {
        guard !space.isCreator, space.status == .active || space.status == .paused, let userID = session.user?.id,
              UUID(uuidString: space.profileID) != nil else { throw UFitBrandCommerceContractError.document }
        self.brandID = space.profileID.lowercased(); self.brandName = space.name; self.session = session; self.userID = userID
    }
    var hasChanges: Bool { draft != baseline }
    var isCurrentAccount: Bool { session.user?.id == userID }
    func load() async {
        guard !isLoading, !isSaving, isCurrentAccount else { return }
        isLoading = true; message = nil
        defer { isLoading = false }
        do {
            async let options = session.api.fetchBrandCommerceMetadata()
            async let current = session.api.fetchManagedBrandCommercePolicy(brandID: brandID)
            let (metadata, result) = try await (options, current)
            let values = try Self.draft(result, metadata: metadata)
            guard isCurrentAccount else { return }
            currencies = metadata.currencies; countries = metadata.choices
            document = result; draft = values; baseline = values; errors = [:]; hasLoaded = true
        } catch { if isCurrentAccount { message = error.localizedDescription } }
    }
    func save() async {
        guard hasLoaded, hasChanges, !isLoading, !isSaving, isCurrentAccount, let document else { return }
        errors = UFitBrandCommerceValidation.policy(draft, countries: countries, currencies: currencies)
        guard errors.isEmpty else { message = Copy.invalid; return }
        isSaving = true; message = nil
        defer { isSaving = false }
        do {
            let policy = try draft.policy(countries: countries, currencies: currencies)
            let saved = try await session.api.saveBrandCommercePolicy(brandID: brandID, version: document.version, policy: policy)
            let metadata = UFitBrandCommerceMetadata(countries: countries.map(\.id), currencies: currencies)
            let values = try Self.draft(saved, metadata: metadata)
            guard isCurrentAccount else { return }
            self.document = saved; draft = values; baseline = values; message = Copy.saved
        } catch { if isCurrentAccount { message = (error as? UFitAPIError)?.isInvalidBrandCommercePolicy == true ? Copy.invalid : error.localizedDescription } }
    }
    private static func draft(_ document: UFitManagedBrandCommercePolicy, metadata: UFitBrandCommerceMetadata) throws -> UFitBrandCommerceDraft {
        guard let policy = document.policy else { return UFitBrandCommerceDraft() }
        let value = try UFitBrandCommerceDraft(policy: policy, currencies: metadata.currencies)
        guard UFitBrandCommerceValidation.policy(value, countries: metadata.choices, currencies: metadata.currencies).isEmpty else { throw UFitBrandCommerceContractError.document }
        return value
    }
}
