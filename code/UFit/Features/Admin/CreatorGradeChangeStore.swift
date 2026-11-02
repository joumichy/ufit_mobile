import Foundation
import Observation

@MainActor @Observable
final class UFitCreatorGradeChangeStore {
    var draft = UFitCreatorGradeChangeDraft()
    private(set) var reference: UFitCreatorGradeAssignmentDTO
    private(set) var errors: [UFitCreatorGradeChangeField: String] = [:]
    private(set) var isBusy = false
    private(set) var isReloading = false
    private(set) var message: String?
    private(set) var messageIsError = false
    private(set) var referenceIsStale = false
    let detail: UFitCreatorGradeAssignmentDetailStore
    let choices: UFitCreatorGradesStore
    @ObservationIgnored private var selectedUnavailable = false
    @ObservationIgnored private var baseline = UFitCreatorGradeChangeDraft()
    @ObservationIgnored private var generation = UUID()
    init(detail: UFitCreatorGradeAssignmentDetailStore) throws {
        guard detail.isCurrentAccount, detail.canChangeGrade else { throw UFitCreatorGradeFailure.input }
        self.detail = detail; reference = detail.assignment
        choices = UFitCreatorGradesStore(session: detail.collection.session)
    }
    var isCurrentAccount: Bool { detail.isCurrentAccount }
    var hasChanges: Bool { draft != baseline }
    var canChangeGrade: Bool { reference.accountStatus == .active && (reference.creatorStatus == .active || reference.creatorStatus == .paused) }
    func cancelLoading() { generation = UUID(); isBusy = false; isReloading = false; choices.cancelLoading() }
    func clearError(_ field: UFitCreatorGradeChangeField) { errors[field] = nil }
    func canSelect(_ grade: UFitCreatorGradeRow) -> Bool {
        isCurrentAccount && canChangeGrade && !isBusy && !isReloading && !referenceIsStale && grade.id != reference.gradeCode && grade.assignable && choices.grades.contains { $0.code == grade.id && $0.assignable }
    }
    func choose(_ grade: UFitCreatorGradeRow) {
        guard canSelect(grade) else { return }
        selectedUnavailable = false
        draft.grade = grade; errors[.grade] = nil; message = nil; messageIsError = false
    }
    func reloadReference() async {
        guard isCurrentAccount, !isBusy, !isReloading else { return }
        let request = generation
        isReloading = true; message = nil; messageIsError = false
        defer { if generation == request { isReloading = false } }
        do {
            let current = try await detail.collection.session.api.fetchCreatorGradeAssignment(creatorID: reference.creatorId)
            guard generation == request, isCurrentAccount else { return }
            if let selected = draft.grade {
                do {
                    let grade = try await detail.collection.session.api.fetchCreatorGrade(code: selected.id)
                    guard generation == request, isCurrentAccount else { return }
                    draft.grade = grade.row; selectedUnavailable = !grade.assignable
                    errors[.grade] = grade.assignable && grade.code != current.gradeCode ? nil : Copy.choose
                } catch {
                    guard generation == request, isCurrentAccount else { return }
                    guard case UFitAPIError.requestFailed(let status, _, _) = error, status == HTTP.notFound else { throw error }
                    selectedUnavailable = true; errors[.grade] = Copy.unavailable
                }
            }
            reference = current; referenceIsStale = false; message = UFitCreatorGradeAdminCopy.assignmentUpdated
        } catch { if generation == request && isCurrentAccount { report(error) } }
    }
    func save() async -> UFitCreatorGradeAssignmentDTO? {
        guard isCurrentAccount, canChangeGrade, !isBusy, !isReloading, !referenceIsStale, hasChanges, let actorID = detail.collection.session.user?.id else { return nil }
        errors = [:]
        if selectedUnavailable || draft.grade == nil || draft.grade?.id == reference.gradeCode || draft.grade?.assignable != true { errors[.grade] = Copy.choose }
        if !UFitServerTextInput.valid(draft.reason, maximum: UFitCreatorGradeContract.reasonLimit) { errors[.reason] = Copy.reason }
        guard errors.isEmpty, let selected = draft.grade else { return nil }
        let request = generation, current = reference, submitted = draft, reason = UFitServerTextInput.trimmed(draft.reason)
        isBusy = true; message = nil; messageIsError = false
        defer { if generation == request { isBusy = false } }
        do {
            let result: UFitCreatorGradeAssignmentDTO
            do { result = try await detail.collection.session.api.changeCreatorGrade(current, gradeCode: selected.id, reason: reason, actorID: actorID).assignment }
            catch {
                guard generation == request, isCurrentAccount, UFitCreatorGradeAdminFailure.uncertain(error),
                      let recovered = try? await recover(current, gradeCode: selected.id, reason: reason, actorID: actorID) else { throw error }
                result = recovered
            }
            guard generation == request, isCurrentAccount else { return nil }
            reference = result; baseline = submitted; return result
        } catch {
            if generation == request && isCurrentAccount { report(error) }
            return nil
        }
    }
    func report(_ error: Error) {
        detail.collection.report(error)
        messageIsError = true
        if UFitCreatorGradeAdminFailure.conflict(error) { referenceIsStale = true }
        message = failureMessage(error)
    }
    private func recover(_ previous: UFitCreatorGradeAssignmentDTO, gradeCode: String, reason: String, actorID: String) async throws -> UFitCreatorGradeAssignmentDTO? {
        guard isCurrentAccount else { return nil }
        let current = try await detail.collection.session.api.fetchCreatorGradeAssignment(creatorID: previous.creatorId)
        guard isCurrentAccount, current.version == previous.version + UFitCreatorGradeContract.versionStep, current.gradeCode == gradeCode else { return nil }
        let page = try await detail.collection.session.api.fetchCreatorGradeAssignmentHistory(creatorID: previous.creatorId)
        guard isCurrentAccount, page.items.contains(where: { $0.version == current.version && $0.source == .administration && $0.fromGradeCode == previous.gradeCode && $0.toGradeCode == gradeCode && $0.changedByUserId == actorID && $0.reason == reason }) else { return nil }
        return current
    }
    private func failureMessage(_ error: Error) -> String {
        if case UFitAPIError.requestFailed(let status, _, _) = error, status == HTTP.conflict { return UFitCreatorGradeAdminCopy.assignmentChanged }
        return UFitCreatorGradeAdminFailure.message(error)
    }
    private enum HTTP { static let conflict = 409; static let notFound = 404 }
    private enum Copy {
        static let unavailable = String(localized: "Ce grade n’est plus disponible. Choisissez un autre grade.")
        static let choose = String(localized: "Choisissez un grade différent du grade actuel.")
        static let reason = String(localized: "Ajoutez un motif de 1 à 500 caractères.")
    }
}
