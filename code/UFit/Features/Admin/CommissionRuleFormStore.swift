import Foundation
import Observation

@MainActor @Observable
final class UFitCommissionRuleFormStore {
    var draft: UFitCommissionRuleDraft
    private(set) var errors: [UFitCommissionRuleField: String] = [:]
    private(set) var isBusy = false
    private(set) var isReloading = false
    private(set) var message: String?
    private(set) var original: UFitCommissionRuleDTO?
    let collection: UFitCommissionRulesStore
    @ObservationIgnored private var baseline: UFitCommissionRuleDraft
    @ObservationIgnored private var generation = UUID()
    init(collection: UFitCommissionRulesStore, original: UFitCommissionRuleDTO?) throws {
        guard collection.isCurrentAccount else { throw UFitAPIError.authenticationRequired }
        self.collection = collection; self.original = original
        let initial = original?.editingDraft ?? UFitCommissionRuleDraft()
        draft = initial; baseline = initial
    }
    var isNew: Bool { original == nil }
    var hasChanges: Bool { draft != baseline }
    var isCurrentAccount: Bool { collection.isCurrentAccount }
    func cancelLoading() { generation = UUID(); isBusy = false; isReloading = false }
    func report(_ error: Error) { message = UFitCommissionAdminFailure.message(error, isNew: isNew) }
    func reference(_ kind: UFitCommissionReferenceKind) -> UFitCommissionReference? {
        switch kind { case .brand: draft.brand; case .product: draft.product; case .grade: draft.grade }
    }
    func choose(_ value: UFitCommissionReference?, kind: UFitCommissionReferenceKind) {
        guard isCurrentAccount, isNew, !isBusy else { return }
        switch kind {
        case .brand:
            guard let value else { return }
            if draft.brand?.id != value.id { draft.product = nil }
            draft.brand = value; errors[.brand] = nil
        case .product: draft.product = value
        case .grade: draft.grade = value
        }
        message = nil
    }
    func reloadReference() async {
        guard isCurrentAccount, let original, !isBusy, !isReloading else { return }
        let request = generation
        isReloading = true; message = nil
        defer { if generation == request { isReloading = false } }
        do {
            let value = try await collection.session.api.fetchCommissionRule(scopeID: original.scopeId)
            guard generation == request, isCurrentAccount else { return }
            self.original = value; baseline = value.editingDraft; message = Copy.referenceUpdated
        } catch { if generation == request && isCurrentAccount { message = UFitCommissionAdminFailure.message(error) } }
    }
    func save() async -> UFitCommissionRuleDTO? {
        guard isCurrentAccount, !isBusy, !isReloading, hasChanges, let actorID = collection.session.user?.id else { return nil }
        errors = UFitCommissionRuleInput.errors(draft)
        guard errors.isEmpty, let brand = draft.brand else { return nil }
        let request = generation, original = original, submitted = draft
        isBusy = true; message = nil
        defer { if generation == request { isBusy = false } }
        do {
            let configuration = try UFitCommissionRuleInput.configuration(submitted)
            let result: UFitCommissionRuleDTO
            do {
                if let original { result = try await collection.session.api.reviseCommissionRule(original, configuration: configuration, actorID: actorID) }
                else { result = try await collection.session.api.createCommissionRule(brandID: brand.id, productID: submitted.product?.id, gradeCode: submitted.grade?.id, configuration: configuration, actorID: actorID) }
            } catch {
                guard !(error is UFitAPIError), let recovered = try? await recover(submitted, original: original, configuration: configuration, actorID: actorID) else { throw error }
                result = recovered
            }
            guard generation == request, isCurrentAccount else { return nil }
            baseline = submitted; return result
        } catch {
            if generation == request && isCurrentAccount { message = UFitCommissionAdminFailure.message(error, isNew: original == nil) }
            return nil
        }
    }
    private func recover(_ submitted: UFitCommissionRuleDraft, original: UFitCommissionRuleDTO?, configuration: UFitCommissionRuleConfiguration, actorID: String) async throws -> UFitCommissionRuleDTO? {
        guard let brand = submitted.brand, isCurrentAccount else { return nil }
        if let original {
            let current = try await collection.session.api.fetchCommissionRule(scopeID: original.scopeId)
            return current.previousRuleId == original.id && current.createdByUserId == actorID &&
                current.matches(brandID: brand.id, productID: submitted.product?.id, gradeCode: submitted.grade?.id, configuration: configuration) ? current : nil
        }
        var cursor: String?, seen = Set<String>()
        repeat {
            guard isCurrentAccount else { return nil }
            let page = try await collection.session.api.fetchCommissionRules(brandID: brand.id, cursor: cursor)
            for rule in page.items {
                guard seen.insert(rule.id).inserted else { throw UFitCommissionRuleFailure.page }
                if rule.revision == UFitCommissionRuleContract.initialRevision, rule.createdByUserId == actorID,
                    rule.matches(brandID: brand.id, productID: submitted.product?.id, gradeCode: submitted.grade?.id, configuration: configuration) { return rule }
            }
            cursor = page.nextCursor
        } while cursor != nil
        return nil
    }
    private enum Copy { static let referenceUpdated = String(localized: "La référence est à jour. Vérifiez votre saisie avant d’enregistrer la révision.") }
}
