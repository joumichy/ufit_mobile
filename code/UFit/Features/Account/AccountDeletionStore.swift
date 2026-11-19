import Foundation
import Observation

@MainActor @Observable
final class UFitAccountDeletionStore {
    private(set) var isBusy = false
    private(set) var message: String?
    private var request: UFitAccountDeletionRequest?
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let vault = UFitAccountDeletionKeychain()
    @ObservationIgnored private var restored = false
    var showsBrandConsequences: Bool { session.user?.isBrandMember == true }
    var showsCreatorConsequences: Bool { session.user?.isCreator == true }
    var canConfirm: Bool { !isBusy && session.isSignedIn && session.user != nil && session.accountDeletionSubject != nil }
    init(session: UFitSessionStore) { self.session = session }

    func restore() async {
        guard !restored else { return }; restored = true
        do { request = try vault.read() }
        catch { return }
        // Recovery is internal: a lost acknowledgement never creates a tracking journey.
        if let command = request, command.receipt == nil,
           let receipt = try? await session.api.accountDeletionReceipt(command) {
            try? await accept(receipt)
        } else { await reconcileSession() }
    }

    func reconcileSession() async {
        guard let current = request, current.receipt != nil,
              let subject = UUID(uuidString: current.authSubject) else { return }
        var cleaned = false
        do {
            try UFitShippingAddressJournal(userID: current.userID, endpoint: session.api.configuration.baseURL).clear()
            try UFitCheckoutJournal(userID: current.userID, endpoint: session.api.configuration.baseURL).resolve()
            cleaned = true
        } catch { /* Keep the private recovery record for the next lifecycle retry. */ }
        // A local cleanup failure must never keep a deleted account signed in.
        await session.closeDeletedAccount(subject: subject)
        guard cleaned, request?.id == current.id else { return }
        do { try vault.clear(); request = nil }
        catch { /* The accepted request remains private and is retried automatically. */ }
    }

    func confirm() async -> Bool {
        guard canConfirm, let userID = session.user?.id, let subject = session.accountDeletionSubject else { return false }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            if let current = request, current.userID != userID || current.authSubject != subject.uuidString.lowercased() {
                if let receipt = try await session.api.accountDeletionReceipt(current) { try await accept(receipt) }
                else { try vault.clear(); request = nil }
                guard request == nil else { message = UFitAccountDeletionCopy.authority; return false }
            }
            let client = try await session.accountDeletionClient(userID: userID, subject: subject)
            guard session.user?.id == userID, session.accountDeletionSubject == subject, session.isSignedIn else { return false }
            let command = try request ?? UFitAccountDeletionRequest.create(userID: userID, authSubject: subject)
            // Persist only for idempotent recovery if the response or process is lost.
            try vault.save(command); request = command
            do { try await accept(client.requestAccountDeletion(command)); return true }
            catch {
                let submissionError = error
                if let current = try? await session.api.accountDeletionReceipt(command) {
                    try await accept(current); return true
                }
                if case UFitAPIError.requestFailed(_, _, let code) = submissionError,
                   code == UFitAccountDeletionCopy.administratorCode || code == UFitAccountDeletionCopy.authorityCode {
                    try vault.clear(); request = nil
                    message = code == UFitAccountDeletionCopy.administratorCode ? UFitAccountDeletionCopy.administrator : UFitAccountDeletionCopy.authority
                } else { message = UFitAccountDeletionCopy.uncertainDetail }
            }
        } catch is CancellationError { return false }
        catch { message = error.localizedDescription }
        return false
    }

    private func accept(_ receipt: UFitAccountDeletionReceipt) async throws {
        guard var current = request else { throw UFitAccountDeletionFailure.receipt }
        try receipt.validate(requestID: current.id)
        if let previous = current.receipt {
            guard previous.requestedAt == receipt.requestedAt,
                  previous.phase != .completed || previous.completedAt == receipt.completedAt && receipt.phase == .completed,
                  previous.phase != .revoking || receipt.phase != .purging else { throw UFitAccountDeletionFailure.receipt }
        }
        current.receipt = receipt; request = current
        // The server has already closed and anonymized the business account atomically.
        // Media cleanup and identity-provider revocation continue without user action.
        try? vault.save(current)
        await reconcileSession()
    }
}
