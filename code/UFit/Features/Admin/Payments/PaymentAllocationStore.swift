import Foundation
import Observation

@MainActor @Observable
final class UFitPaymentAllocationStore {
    enum Operation { case idle, loading, preparing }
    let reference: UFitPaymentSettlementDocument; let brandID: String; let collection: UFitAdminOrdersStore
    private(set) var operation = Operation.idle
    private(set) var message: String?
    private(set) var messageIsError = true
    private(set) var needsStatusRefresh = false
    private(set) var readFailed = false
    private var received: UFitPaymentAllocationDocument?
    @ObservationIgnored private var generation = UUID()
    init(reference: UFitPaymentSettlementDocument, brandID: String, collection: UFitAdminOrdersStore) {
        self.reference = reference; self.brandID = brandID; self.collection = collection
    }
    var document: UFitPaymentAllocationDocument? { collection.canRead ? received : nil }
    var isLoading: Bool { operation == .loading }
    var isSending: Bool { operation == .preparing }
    var canPrepare: Bool { document?.state == .notPrepared && !isLoading && !isSending && !needsStatusRefresh && !readFailed }
    func cancelLoading() {
        generation = UUID()
        if isSending { needsStatusRefresh = true; message = UFitPaymentAllocationCopy.unconfirmed; messageIsError = true }
        operation = .idle
    }
    func refresh() async { guard !isSending else { return }; cancelLoading(); await load() }
    func load() async {
        guard collection.canRead, operation == .idle else { return }
        let request = generation, access = collection.epoch
        operation = .loading; message = nil; messageIsError = true
        defer { if generation == request { operation = .idle } }
        do {
            let document = try await collection.session.api.fetchPaymentAllocation(reference: reference, brandID: brandID)
            guard current(request, access: access) else { return }; accept(document)
        } catch {
            guard current(request, access: access), !Task.isCancelled else { return }
            if !terminal(error) {
                readFailed = true
                if case UFitAPIError.requestFailed(_, _, let code) = error, code == UFitPaymentAllocationHTTP.persisted { message = UFitPaymentAllocationCopy.invalid }
                else { message = error is UFitPaymentAllocationFailure || error is DecodingError ? UFitPaymentAllocationCopy.invalid : UFitPaymentAllocationCopy.loadFailed }
            }
        }
    }
    func prepare() async {
        guard canPrepare else { return }
        let request = generation, access = collection.epoch
        operation = .preparing; message = nil; messageIsError = true
        defer { if generation == request { operation = .idle } }
        do {
            let document = try await collection.session.api.preparePaymentAllocation(reference: reference, brandID: brandID)
            guard current(request, access: access) else { return }; accept(document)
        } catch {
            guard current(request, access: access), !Task.isCancelled else { return }
            if terminal(error) { return }
            needsStatusRefresh = true; readFailed = true
            // Preparation is unique per payment. Confirm its canonical result before offering another POST.
            do {
                let document = try await collection.session.api.fetchPaymentAllocation(reference: reference, brandID: brandID)
                guard current(request, access: access) else { return }; accept(document)
                if document.state == .notPrepared { message = UFitPaymentAllocationCopy.notStarted; messageIsError = false }
            } catch {
                guard current(request, access: access), !Task.isCancelled else { return }
                if !terminal(error) { message = UFitPaymentAllocationCopy.unconfirmed }
            }
        }
    }
    private func accept(_ document: UFitPaymentAllocationDocument) {
        received = document; needsStatusRefresh = false; readFailed = false; message = nil
    }
    private func current(_ request: UUID, access: UUID) -> Bool {
        generation == request && collection.epoch == access && collection.canRead
    }
    private func terminal(_ error: Error) -> Bool {
        if UFitAdminOrdersError.revoked(error) { received = nil; collection.revoke(); return true }
        if case UFitAPIError.requestFailed(let status, _, _) = error, status == UFitPaymentAllocationHTTP.missing {
            received = nil; needsStatusRefresh = false; readFailed = true; message = UFitPaymentAllocationCopy.missing; return true
        }
        return false
    }
}
