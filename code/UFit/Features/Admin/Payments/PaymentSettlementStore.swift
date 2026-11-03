import Foundation
import Observation

@MainActor @Observable
final class UFitPaymentSettlementStore {
    enum Operation { case idle, loading, synchronizing, polling }
    let paymentID: String; let orderID: String; let collection: UFitAdminOrdersStore
    private(set) var operation = Operation.idle
    private(set) var message: String?
    private(set) var needsStatusRefresh = false
    private var received: UFitPaymentSettlementDocument?
    @ObservationIgnored private var generation = UUID()
    init(paymentID: String, orderID: String, collection: UFitAdminOrdersStore) {
        self.paymentID = paymentID; self.orderID = orderID; self.collection = collection
    }
    var document: UFitPaymentSettlementDocument? { collection.canRead ? received : nil }
    var isLoading: Bool { operation == .loading }
    var isSending: Bool { operation == .synchronizing }
    var shouldPoll: Bool { collection.canRead && received?.waitsForReceipt == true && message == nil && !needsStatusRefresh && !isSending }
    func cancelLoading() { generation = UUID(); operation = .idle }
    func refresh() async { guard !isSending else { return }; cancelLoading(); await load() }
    func load(quiet: Bool = false) async {
        guard collection.canRead, operation == .idle else { return }
        let request = generation, access = collection.epoch
        operation = quiet ? .polling : .loading
        if !quiet { message = nil }
        defer { if generation == request { operation = .idle } }
        do {
            let document = try await collection.session.api.fetchPaymentSettlement(paymentID: paymentID, orderID: orderID)
            guard current(request, access: access) else { return }
            received = document; needsStatusRefresh = false; message = nil
        } catch {
            guard current(request, access: access), !Task.isCancelled else { return }
            if !terminal(error) { message = error is UFitPaymentSettlementFailure ? UFitPaymentSettlementCopy.invalid : UFitPaymentSettlementCopy.loadFailed }
        }
    }
    func synchronize() async {
        guard collection.canRead, !isLoading, !isSending, !needsStatusRefresh else { return }
        cancelLoading()
        let request = generation, access = collection.epoch
        operation = .synchronizing; message = nil
        defer { if generation == request { operation = .idle } }
        do {
            let document = try await collection.session.api.synchronizePaymentSettlement(paymentID: paymentID, orderID: orderID)
            guard current(request, access: access) else { return }
            received = document; needsStatusRefresh = false
        } catch {
            guard current(request, access: access), !Task.isCancelled else { return }
            if terminal(error) { return }
            needsStatusRefresh = true
            // The request may have committed: read its canonical state before offering another request.
            do {
                let document = try await collection.session.api.fetchPaymentSettlement(paymentID: paymentID, orderID: orderID)
                guard current(request, access: access) else { return }
                received = document; needsStatusRefresh = false
                message = document.state == .notRequested ? UFitPaymentSettlementCopy.notStarted : nil
            } catch {
                guard current(request, access: access), !Task.isCancelled else { return }
                if !terminal(error) { message = UFitPaymentSettlementCopy.unconfirmed }
            }
        }
    }
    private func current(_ request: UUID, access: UUID) -> Bool {
        generation == request && collection.epoch == access && collection.canRead
    }
    private func terminal(_ error: Error) -> Bool {
        if UFitAdminOrdersError.revoked(error) { received = nil; collection.revoke(); return true }
        if case UFitAPIError.requestFailed(let status, _, let code) = error {
            if status == UFitPaymentSettlementHTTP.missing {
                received = nil; needsStatusRefresh = false; message = UFitPaymentSettlementCopy.missing; return true
            }
            if code == UFitPaymentSettlementHTTP.unsupported {
                received = nil; needsStatusRefresh = false; message = UFitPaymentSettlementCopy.unsupported; return true
            }
        }
        return false
    }
}
