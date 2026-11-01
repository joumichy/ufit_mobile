import Foundation
import Observation

@MainActor @Observable
final class UFitCreatorGradeFormStore {
    var draft: UFitCreatorGradeDraft
    private(set) var errors: [UFitCreatorGradeField: String] = [:]
    private(set) var isBusy = false
    private(set) var isReloading = false
    private(set) var message: String?
    private(set) var original: UFitCreatorGradeDTO?
    let collection: UFitCreatorGradesStore
    @ObservationIgnored private var baseline: UFitCreatorGradeDraft
    @ObservationIgnored private var generation = UUID()
    init(collection: UFitCreatorGradesStore, original: UFitCreatorGradeDTO?) throws {
        guard collection.isCurrentAccount else { throw UFitAPIError.authenticationRequired }
        self.collection = collection; self.original = original
        let initial = original?.editingDraft ?? UFitCreatorGradeDraft()
        draft = initial; baseline = initial
    }
    var isNew: Bool { original == nil }
    var hasChanges: Bool { draft != baseline }
    var isCurrentAccount: Bool { collection.isCurrentAccount }
    func cancelLoading() { generation = UUID(); isBusy = false; isReloading = false }
    func clearError(_ field: UFitCreatorGradeField) { errors[field] = nil }
    func reloadReference() async {
        guard isCurrentAccount, let original, !isBusy, !isReloading else { return }
        let request = generation
        isReloading = true; message = nil
        defer { if generation == request { isReloading = false } }
        do {
            let current = try await collection.session.api.fetchCreatorGrade(code: original.code)
            guard generation == request, isCurrentAccount else { return }
            self.original = current; baseline = current.editingDraft; message = Copy.referenceUpdated
        } catch { if generation == request && isCurrentAccount { message = UFitCreatorGradeAdminFailure.message(error) } }
    }
    func save() async -> UFitCreatorGradeDTO? {
        guard isCurrentAccount, !isBusy, !isReloading, hasChanges, let actorID = collection.session.user?.id else { return nil }
        errors = UFitCreatorGradeInput.errors(draft, originalCode: original?.code)
        guard errors.isEmpty else { return nil }
        let request = generation, original = original, submitted = draft
        isBusy = true; message = nil
        defer { if generation == request { isBusy = false } }
        do {
            let configuration = try UFitCreatorGradeInput.configuration(submitted, originalCode: original?.code)
            let result: UFitCreatorGradeDTO
            do {
                if let original { result = try await collection.session.api.reviseCreatorGrade(original, configuration: configuration) }
                else { result = try await collection.session.api.createCreatorGrade(code: submitted.code, configuration: configuration) }
            } catch {
                guard generation == request, isCurrentAccount, UFitCreatorGradeAdminFailure.uncertain(error), let recovered = try? await recover(submitted, original: original, configuration: configuration, actorID: actorID) else { throw error }
                result = recovered
            }
            guard generation == request, isCurrentAccount else { return nil }
            baseline = submitted; return result
        } catch {
            if generation == request && isCurrentAccount { message = UFitCreatorGradeAdminFailure.message(error, isNew: original == nil) }
            return nil
        }
    }
    private func recover(_ submitted: UFitCreatorGradeDraft, original: UFitCreatorGradeDTO?, configuration: UFitCreatorGradeConfiguration, actorID: String) async throws -> UFitCreatorGradeDTO? {
        guard isCurrentAccount else { return nil }
        let current = try await collection.session.api.fetchCreatorGrade(code: submitted.code)
        let expectedVersion = original.map { $0.version + UFitCreatorGradeContract.versionStep } ?? UFitCreatorGradeContract.initialVersion
        guard isCurrentAccount, current.version == expectedVersion, current.matches(configuration) else { return nil }
        let history = try await collection.session.api.fetchCreatorGradeHistory(code: submitted.code)
        guard isCurrentAccount, let revision = history.items.first, revision.id == current.revisionId,
              revision.previousRevisionId == original?.revisionId, revision.changedByUserId == actorID, revision.reason == configuration.reason else { return nil }
        return current
    }
    private enum Copy { static let referenceUpdated = String(localized: "La référence est à jour. Vérifiez votre saisie avant d’enregistrer.") }
}
