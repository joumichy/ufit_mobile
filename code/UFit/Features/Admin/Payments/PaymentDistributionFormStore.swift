import Foundation
import Observation

@MainActor @Observable
final class UFitDistributionFormStore {
    enum PendingState { case unconfirmed, notRecorded }
    let detail: UFitDistributionDetailStore
    var draft: UFitDistributionDraft
    private(set) var reference: UFitDistributionDocument
    private(set) var errors = [UFitDistributionField: String]()
    private(set) var validationAttempt = UUID()
    private(set) var isBusy = false
    private(set) var isReloading = false
    private(set) var referenceIsStale = false
    private(set) var message: String?
    private(set) var messageIsError = true
    private(set) var pendingState: PendingState?
    @ObservationIgnored private var baseline: UFitDistributionDraft
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var pending: UFitDistributionChangeBody?
    @ObservationIgnored private var pendingPreviousID: String?
    init(detail: UFitDistributionDetailStore, reference: UFitDistributionDocument) {
        self.detail = detail; self.reference = reference
        let initial = UFitDistributionDraft(policy: reference.current); draft = initial; baseline = initial
    }
    var isAvailable: Bool { detail.collection.canRead && detail.document != nil }
    var hasChanges: Bool { draft != baseline }
    var fieldsLocked: Bool { isBusy || isReloading || pending != nil }
    var canSubmit: Bool { !isBusy && !isReloading && !referenceIsStale && (reference.current == nil || hasChanges || pending != nil) }
    var actionTitle: String { pendingState == .unconfirmed ? UFitDistributionCopy.check : pendingState == .notRecorded ? UFitDistributionCopy.retrySave : UFitDistributionCopy.save }
    func clearError(_ field: UFitDistributionField) { errors[field] = nil }
    func cancelLoading() {
        generation = UUID(); isBusy = false; isReloading = false
        if pending != nil && pendingState == nil { pendingState = .unconfirmed; message = UFitDistributionCopy.unconfirmed; messageIsError = true }
    }
    private func current(_ request: UUID, epoch: UUID) -> Bool { generation == request && detail.collection.epoch == epoch && isAvailable }
    func submit() async -> UFitDistributionChangeResult? {
        guard isAvailable, canSubmit else { return nil }
        if pendingState == .unconfirmed { return await check() }
        if pending == nil {
            errors = draft.errors
            if !errors.isEmpty { validationAttempt = UUID() }
            guard errors.isEmpty, let rate = draft.rateBps, let bearer = draft.bearer else { return nil }
            pending = .init(requestId: UUID().uuidString.lowercased(), expectedRevision: reference.current?.revision ?? .zero,
                platformRateBps: rate, feeBearer: bearer, active: draft.active, reason: UFitServerTextInput.trimmed(draft.reason))
            pendingPreviousID = reference.current?.id
        }
        guard let body = pending else { return nil }
        let request = generation, epoch = detail.collection.epoch
        isBusy = true; message = nil; messageIsError = true
        defer { if generation == request { isBusy = false } }
        do {
            let result = try await detail.collection.session.api.reviseDistribution(brandID: detail.brandID, body: body, previousID: pendingPreviousID)
            guard current(request, epoch: epoch) else { return nil }; accept(result); return result
        } catch {
            guard current(request, epoch: epoch), !Task.isCancelled else { return nil }
            if terminal(error) { return nil }
            pendingState = .unconfirmed
            return await reconcile(body, request: request, epoch: epoch)
        }
    }
    func check() async -> UFitDistributionChangeResult? {
        guard isAvailable, !isBusy, !isReloading, let body = pending else { return nil }
        let request = generation, epoch = detail.collection.epoch
        isBusy = true; message = nil; messageIsError = true
        defer { if generation == request { isBusy = false } }
        return await reconcile(body, request: request, epoch: epoch)
    }
    private func reconcile(_ body: UFitDistributionChangeBody, request: UUID, epoch: UUID) async -> UFitDistributionChangeResult? {
        do {
            let result = try await detail.collection.session.api.fetchDistributionChange(brandID: detail.brandID, body: body, previousID: pendingPreviousID)
            guard current(request, epoch: epoch) else { return nil }; accept(result); return result
        } catch {
            guard current(request, epoch: epoch), !Task.isCancelled else { return nil }
            if terminal(error) { return nil }
            if UFitDistributionError.code(error, equals: UFitDistributionHTTP.changeMissing) {
                pendingState = .notRecorded; message = UFitDistributionCopy.notRecorded; messageIsError = false
            } else { pendingState = .unconfirmed; message = UFitDistributionCopy.unconfirmed }
            return nil
        }
    }
    private func accept(_ result: UFitDistributionChangeResult) {
        detail.accept(result.document); reference = result.document; baseline = draft
        pending = nil; pendingPreviousID = nil; pendingState = nil; message = nil
    }
    func reloadReference() async {
        guard isAvailable, !isBusy, !isReloading, pending == nil else { return }
        let request = generation, epoch = detail.collection.epoch
        isReloading = true; message = nil; messageIsError = true
        defer { if generation == request { isReloading = false } }
        do {
            let result = try await detail.collection.session.api.fetchDistribution(brandID: detail.brandID)
            guard current(request, epoch: epoch) else { return }
            detail.accept(result); reference = result; baseline = .init(policy: result.current)
            referenceIsStale = false; message = UFitDistributionCopy.referenceUpdated; messageIsError = false
        } catch {
            guard current(request, epoch: epoch), !Task.isCancelled else { return }
            if !terminal(error) { message = UFitDistributionError.message(error) }
        }
    }
    private func terminal(_ error: Error) -> Bool {
        if UFitDistributionError.revoked(error) { pending = nil; pendingState = nil; detail.collection.revoke(); return true }
        if UFitDistributionError.code(error, equals: UFitDistributionHTTP.brandMissing) { pending = nil; pendingState = nil; detail.missing(); return true }
        if UFitDistributionError.conflict(error) {
            pending = nil; pendingPreviousID = nil; pendingState = nil; referenceIsStale = true
            message = UFitDistributionCopy.changed; return true
        }
        if case UFitAPIError.requestFailed(let status, _, _) = error, status == UFitDistributionHTTP.badInput {
            pending = nil; pendingPreviousID = nil; pendingState = nil; message = UFitDistributionCopy.invalid; return true
        }
        return false
    }
}
