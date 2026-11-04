import Foundation
import Observation

@MainActor @Observable
final class UFitAccountDeletionStore {
    private(set) var request: UFitAccountDeletionRequest?
    private(set) var isBusy = false
    private(set) var isSending = false
    private var failure: String?
    private var absenceConfirmed = false
    private(set) var storageFailed = false
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let vault = UFitAccountDeletionKeychain()
    @ObservationIgnored private var restored = false
    var canResubmit: Bool { absenceConfirmed && matchesAccount }
    var message: String? {
        if absenceConfirmed {
            if session.isRestoring { return nil }
            return matchesAccount ? UFitAccountDeletionCopy.unavailable : UFitAccountDeletionCopy.signIn
        }
        return failure
    }
    var hasRequest: Bool { request != nil || storageFailed }
    var receipt: UFitAccountDeletionReceipt? { request?.receipt }
    var isCompleted: Bool { receipt?.phase == .completed }
    var showsBrandConsequences: Bool { session.user?.isBrandMember == true }
    var canConfirm: Bool { !storageFailed && !isBusy && (request == nil || canResubmit) && matchesAccount }
    private var matchesAccount: Bool {
        guard session.isSignedIn, let user = session.user, let subject = session.accountDeletionSubject else { return false }
        guard let request else { return true }
        return request.userID == user.id && request.authSubject == subject.uuidString.lowercased()
    }
    init(session: UFitSessionStore) { self.session = session }
    func restore() async {
        guard !restored else { return }; restored = true
        do { request = try vault.read() }
        catch { storageFailed = true; failure = error.localizedDescription; return }
        await reconcileSession()
        if request != nil { await refresh() }
    }
    func reconcileSession() async {
        if let request, request.receipt != nil, let subject = UUID(uuidString: request.authSubject) {
            do { try UFitCheckoutJournal(userID: request.userID, endpoint: session.api.configuration.baseURL).resolve() }
            catch { failure = UFitCheckoutRecoveryCopy.localRemoval }
            await session.closeDeletedAccount(subject: subject)
        }
    }
    func confirm() async {
        guard canConfirm, let userID = session.user?.id, let subject = session.accountDeletionSubject else { return }
        isBusy = true; isSending = true; failure = nil; absenceConfirmed = false
        defer { isBusy = false; isSending = false }
        do {
            let command = try request ?? UFitAccountDeletionRequest.create(userID: userID, authSubject: subject)
            // Save BEFORE dispatch: a lost response or process termination keeps its capability.
            try vault.save(command); request = command
            do { try await accept(session.api.requestAccountDeletion(command)) }
            catch {
                let submissionError = error
                if let current = try? await session.api.accountDeletionReceipt(command) { try await accept(current); return }
                if case UFitAPIError.requestFailed(_, _, let code) = submissionError,
                   code == UFitAccountDeletionCopy.administratorCode || code == UFitAccountDeletionCopy.authorityCode {
                    // These explicit server refusals happen before the local account is closed.
                    try vault.clear(); request = nil
                    failure = code == UFitAccountDeletionCopy.administratorCode ? UFitAccountDeletionCopy.administrator : UFitAccountDeletionCopy.authority
                } else { failure = UFitAccountDeletionCopy.uncertainDetail }
            }
        } catch { failure = error.localizedDescription }
    }
    func refresh() async {
        guard !isBusy else { return }
        if storageFailed {
            do { request = try vault.read(); storageFailed = false }
            catch { failure = error.localizedDescription; return }
        }
        guard let command = request else { return }
        isBusy = true; failure = nil; absenceConfirmed = false
        defer { isBusy = false }
        do {
            if let result = try await session.api.accountDeletionReceipt(command) { try await accept(result) }
            else { absenceConfirmed = true }
        } catch { failure = receipt == nil ? UFitAccountDeletionCopy.uncertainDetail : error.localizedDescription }
    }
    private func accept(_ receipt: UFitAccountDeletionReceipt) async throws {
        guard var current = request else { throw UFitAccountDeletionFailure.receipt }
        try receipt.validate(requestID: current.id)
        // An older or malformed response must not roll back a confirmed completion.
        if let previous = current.receipt {
            guard previous.requestedAt == receipt.requestedAt,
                  previous.phase != .completed || previous.completedAt == receipt.completedAt && receipt.phase == .completed,
                  previous.phase != .revoking || receipt.phase != .purging else { throw UFitAccountDeletionFailure.receipt }
        }
        current.receipt = receipt; request = current; absenceConfirmed = false
        do { try vault.save(current) }
        catch { await reconcileSession(); throw error }
        failure = nil; await reconcileSession()
    }
    func finish() -> Bool {
        guard isCompleted, !isBusy, let current = request else { return false }
        do { try UFitCheckoutJournal(userID: current.userID, endpoint: session.api.configuration.baseURL).resolve() }
        catch { failure = UFitCheckoutRecoveryCopy.localRemoval; return false }
        do {
            try vault.clear(); request = nil; failure = nil; return true
        }
        catch { failure = error.localizedDescription; return false }
    }
}
