import Foundation
import Observation

@MainActor @Observable
final class UFitPaymentDisbursementStore {
    enum Operation { case idle, loading, reading, resuming }
    let reference: UFitPaymentSettlementDocument; let brandID: String; let collection: UFitAdminOrdersStore
    private(set) var operation = Operation.idle
    private(set) var message: String?
    private(set) var needsStatusRefresh = false
    private(set) var readFailed = false
    private var received: UFitPaymentDisbursementDocument?
    @ObservationIgnored private var generation = UUID()
    init(reference: UFitPaymentSettlementDocument, brandID: String, collection: UFitAdminOrdersStore) {
        self.reference = reference; self.brandID = brandID; self.collection = collection
    }
    var document: UFitPaymentDisbursementDocument? { collection.canRead ? received : nil }
    var isLoading: Bool { operation == .loading }
    var isSending: Bool { operation == .resuming }
    var shouldPoll: Bool { document?.waitsForServer == true && !readFailed && !needsStatusRefresh && collection.canRead }
    var canResume: Bool {
        guard operation == .idle, !needsStatusRefresh, !readFailed, let document, document.allocation.state != .blocked, !document.awaitsConfirmation else { return false }
        switch document.state {
        case .notRequested: return true
        case .needsReview, .waiting: return document.reason?.allowsResume == true
        case .queued, .processing: return false
        }
    }
    func cancelLoading() {
        generation = UUID()
        if isSending { needsStatusRefresh = true; message = UFitPaymentDisbursementCopy.unconfirmed }
        operation = .idle
    }
    func refresh() async { guard !isSending else { return }; cancelLoading(); await load() }
    func load(quiet: Bool = false) async {
        guard collection.canRead, operation == .idle else { return }
        let request = generation, access = collection.epoch
        operation = quiet ? .reading : .loading
        if !quiet { message = nil }
        defer { if generation == request { operation = .idle } }
        do {
            let document = try await collection.session.api.fetchPaymentDisbursements(reference: reference, brandID: brandID)
            guard current(request, access: access) else { return }; accept(document)
        } catch {
            guard current(request, access: access), !Task.isCancelled else { return }
            if !terminal(error) { readFailed = true; message = error is UFitPaymentDisbursementFailure || error is DecodingError ? UFitPaymentDisbursementCopy.invalid : UFitPaymentDisbursementCopy.loadFailed }
        }
    }
    func resume() async {
        guard canResume else { return }
        let request = generation, access = collection.epoch
        operation = .resuming; message = nil
        defer { if generation == request { operation = .idle } }
        do {
            let document = try await collection.session.api.resumePaymentDisbursements(reference: reference, brandID: brandID)
            guard current(request, access: access) else { return }; accept(document)
        } catch {
            guard current(request, access: access), !Task.isCancelled else { return }
            if terminal(error) { return }
            needsStatusRefresh = true; readFailed = true
            // An uncertain command is followed by a canonical read, never an automatic second POST.
            do {
                let document = try await collection.session.api.fetchPaymentDisbursements(reference: reference, brandID: brandID)
                guard current(request, access: access) else { return }; accept(document)
            } catch {
                guard current(request, access: access), !Task.isCancelled else { return }
                if !terminal(error) { message = UFitPaymentDisbursementCopy.unconfirmed }
            }
        }
    }
    private func accept(_ document: UFitPaymentDisbursementDocument) { received = document; needsStatusRefresh = false; readFailed = false; message = nil }
    private func current(_ request: UUID, access: UUID) -> Bool { generation == request && collection.epoch == access && collection.canRead }
    private func terminal(_ error: Error) -> Bool {
        if UFitAdminOrdersError.revoked(error) { received = nil; collection.revoke(); return true }
        if case UFitAPIError.requestFailed(let status, _, _) = error, status == UFitPaymentDisbursementHTTP.missing {
            received = nil; needsStatusRefresh = false; readFailed = true; message = UFitPaymentDisbursementCopy.missing; return true
        }
        return false
    }
}
