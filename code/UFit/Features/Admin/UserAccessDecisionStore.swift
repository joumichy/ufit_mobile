import Foundation
import Observation

@MainActor @Observable
final class UFitUserAccessDecisionStore {
    var reason = String()
    let decision: UFitUserAccessDecision
    let detail: UFitUserAdministrationDetailStore
    private(set) var original: UFitAdministeredUserDTO
    private(set) var reasonError: String?
    private(set) var message: String?
    private(set) var messageIsError = false
    private(set) var isBusy = false
    private(set) var isReloading = false
    private(set) var requiresReferenceReload = false
    private(set) var hasSaved = false
    @ObservationIgnored private var generation = UUID()

    init(detail: UFitUserAdministrationDetailStore, decision: UFitUserAccessDecision) throws {
        guard detail.isCurrentAccount, detail.user.allows(decision) else { throw UFitUserAdministrationFailure.input }
        self.detail = detail; self.decision = decision; original = detail.user
    }
    var isCurrentAccount: Bool { detail.isCurrentAccount }
    var canDecide: Bool { isCurrentAccount && original.allows(decision) && !requiresReferenceReload && !hasSaved }
    var hasChanges: Bool { !reason.isEmpty }
    func cancelLoading() { generation = UUID(); isBusy = false; isReloading = false }
    func clearReasonError() { reasonError = nil }
    func report(_ error: Error) { message = UFitUserAdministrationError.message(error); messageIsError = true }
    func reloadReference() async {
        guard isCurrentAccount, !isBusy, !isReloading, !hasSaved else { return }
        let request = generation
        isReloading = true; message = nil; messageIsError = false
        defer { if generation == request { isReloading = false } }
        do {
            let current = try await detail.collection.session.api.fetchAdministeredUser(id: original.id)
            guard generation == request, isCurrentAccount else { return }
            original = current; requiresReferenceReload = false
            message = current.allows(decision) ? Copy.referenceUpdated : Copy.unavailable
        } catch {
            if generation == request && isCurrentAccount {
                if UFitUserAdministrationError.revoked(error) { detail.collection.recordReadFailure(error) }
                message = UFitUserAdministrationError.message(error); messageIsError = true
            }
        }
    }
    func save() async -> UFitAdministeredUserDTO? {
        guard canDecide, !isBusy, !isReloading, let actorID = detail.collection.session.user?.id else { return nil }
        let submitted = UFitServerTextInput.trimmed(reason)
        guard UFitUserAdministrationContract.reason(submitted) else { reasonError = Copy.reason; return nil }
        let request = generation, original = original
        isBusy = true; message = nil; reasonError = nil; messageIsError = false
        defer { if generation == request { isBusy = false } }
        do {
            let current: UFitAdministeredUserDTO
            do {
                switch decision {
                case .suspend, .activate:
                    current = try await detail.collection.session.api.changeUserStatus(original, status: decision == .suspend ? .suspended : .active, reason: submitted)
                case .grantAdmin, .revokeAdmin:
                    current = try await detail.collection.session.api.changeUserAdminAccess(original, enabled: decision == .grantAdmin, reason: submitted)
                }
            } catch {
                guard generation == request, isCurrentAccount, UFitUserAdministrationError.uncertain(error),
                      let recovered = try? await recover(original: original, reason: submitted, actorID: actorID) else { throw error }
                current = recovered
            }
            guard generation == request, isCurrentAccount else { return nil }
            hasSaved = true
            return current
        } catch {
            guard generation == request, isCurrentAccount else { return nil }
            requiresReferenceReload = UFitUserAdministrationError.conflict(error)
            message = UFitUserAdministrationError.message(error)
            messageIsError = true
            return nil
        }
    }
    private func recover(original: UFitAdministeredUserDTO, reason: String, actorID: String) async throws -> UFitAdministeredUserDTO? {
        guard isCurrentAccount else { return nil }
        let current = try await detail.collection.session.api.fetchAdministeredUser(id: original.id)
        guard isCurrentAccount, current.version == original.version + UFitUserAdministrationContract.versionStep else { return nil }
        let page = try await detail.collection.session.api.fetchUserAccessHistory(userID: original.id)
        guard isCurrentAccount, let change = page.items.first, change.version == current.version,
              change.decidedByUserId == actorID, change.reason == reason, change.fromStatus == original.status,
              change.toStatus == current.status, change.adminBefore == original.roles.contains(.admin),
              change.adminAfter == current.roles.contains(.admin) else { return nil }
        switch decision {
        case .suspend, .activate:
            guard change.kind == .status, current.status == (decision == .suspend ? .suspended : .active), current.roleCodes == original.roleCodes else { return nil }
        case .grantAdmin, .revokeAdmin:
            var expectedRoles = original.roleCodes
            if decision == .grantAdmin { expectedRoles.insert(UFitUserRole.admin.rawValue) } else { expectedRoles.remove(UFitUserRole.admin.rawValue) }
            guard change.kind == .adminAccess, current.status == original.status, current.roleCodes == expectedRoles else { return nil }
        }
        return current
    }
    private enum Copy {
        static let reason = String(localized: "Ajoutez un motif de 1 à 500 caractères.")
        static let referenceUpdated = String(localized: "Les accès sont à jour. Vérifiez la décision. Votre motif est conservé.")
        static let unavailable = String(localized: "Cette décision n’est plus disponible pour ce compte. Votre motif est conservé.")
    }
}

enum UFitUserAdministrationError {
    private enum HTTP { static let unauthorized = 401; static let forbidden = 403; static let conflict = 409; static let unavailable = 500 }
    private enum Copy {
        static let changed = String(localized: "Les accès de ce compte ont changé. Actualisez-les avant de réessayer. Votre motif est conservé.")
    }
    static func revoked(_ error: Error) -> Bool {
        guard case UFitAPIError.requestFailed(let status, _, _) = error else { return false }
        return status == HTTP.unauthorized || status == HTTP.forbidden
    }
    static func conflict(_ error: Error) -> Bool {
        guard case UFitAPIError.requestFailed(let status, _, _) = error else { return false }
        return status == HTTP.conflict
    }
    static func uncertain(_ error: Error) -> Bool {
        if case UFitUserAdministrationFailure.input = error { return false }
        if case UFitAPIError.requestFailed(let status, _, _) = error { return status >= HTTP.unavailable }
        if case UFitAPIError.authenticationRequired = error { return false }
        if case UFitAPIError.invalidURL = error { return false }
        return true
    }
    static func message(_ error: Error) -> String { conflict(error) ? Copy.changed : error.localizedDescription }
}
