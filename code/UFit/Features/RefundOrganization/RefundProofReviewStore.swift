import Foundation
import Observation

@MainActor @Observable
final class UFitRefundProofReviewStore {
    let reference: UFitRefundRecoveryReference
    let amount: String
    private(set) var document: UFitRefundOrganizationDocumentDTO
    var decision: UFitRefundProofDecision? {didSet {if pending == nil {decisionError = nil; message = nil}}}
    var reason = String() {didSet {if pending == nil {reasonError = nil}}}
    var verificationReference = String() {didSet {if pending == nil {referenceError = nil}}}
    private(set) var pending: UFitRefundProofReviewRequest?
    private(set) var isBusy = false
    private(set) var isComplete = false
    private(set) var hasAccess = true
    private(set) var isStale = false
    private(set) var localFailed = false
    private(set) var canRetry = false
    private(set) var message: String?
    private(set) var decisionError: String?
    private(set) var reasonError: String?
    private(set) var referenceError: String?
    private(set) var comparison: UFitRefundOrganizationDocumentDTO?
    @ObservationIgnored private let actorID: String
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var loaded = false
    init(document: UFitRefundOrganizationDocumentDTO, actorID: String, session: UFitSessionStore) {
        self.document = document; reference = document.summary.reference; amount = UFitMoney.format(document.summary.amount, currency: document.summary.currency)
        self.actorID = actorID; self.session = session
    }
    var hasChanges: Bool {decision != nil || !reason.isEmpty || !verificationReference.isEmpty}
    var canUseVersion: Bool {comparison?.proof?.id == document.proof?.id && comparison?.reviewActions.isEmpty == false}
    private var isCurrent: Bool {session.user?.id == actorID && session.user?.canAdminister == true}
    private var journal: UFitRefundProofReviewJournal {.init(actorID: actorID, reference: reference)}
    func cancelLoading() {generation = UUID(); isBusy = false}
    func load() async {
        guard isCurrent, !loaded else {return}; loaded = true
        do {pending = try journal.read(); if let pending {restore(pending); await verify()}}
        catch {localFailed = true; message = UFitRefundReviewCopy.localFailure}
    }
    func save() async {
        guard isCurrent, !isBusy, !isStale, !localFailed, pending == nil else {return}
        guard validateDraft(), let decision, let proof = document.proof, let version = document.organization?.version else {return}
        let command = UFitRefundProofReviewRequest(requestId: UUID().uuidString.lowercased(), expectedVersion: version, proofId: proof.id, decision: decision,
            reason: UFitServerTextInput.trimmed(reason), verificationReference: decision == .confirm ? UFitServerTextInput.trimmed(verificationReference) : nil)
        do {try journal.write(command); pending = command; restore(command); await send()}
        catch {message = error.localizedDescription}
    }
    func validateDraft() -> Bool {
        guard isCurrent, !isBusy, !isStale, !localFailed, pending == nil else {return false}
        decisionError = decision == nil ? UFitRefundOrganizationCopy.required : nil
        reasonError = fieldError(reason, maximum: UFitRefundReviewRules.reasonMaximum)
        referenceError = decision == .confirm ? fieldError(verificationReference, maximum: UFitRefundReviewRules.referenceMaximum) : nil
        guard decisionError == nil, reasonError == nil, referenceError == nil, let decision, document.proof != nil,
              document.reviewActions.contains(decision), document.organization != nil else {message = UFitRefundOrganizationCopy.invalid; return false}
        message = nil; return true
    }
    func send() async {
        guard isCurrent, !isBusy, let pending else {return}; isBusy = true; canRetry = false; let request = generation
        defer {if request == generation {isBusy = false}}
        do {
            let result = try await session.api.reviewRefundProof(reference: reference, request: pending)
            guard request == generation, isCurrent else {return}; try accept(result)
        } catch {
            guard request == generation, isCurrent else {return}
            if case UFitAPIError.requestFailed(let status, _, _) = error, status == UFitRefundOrganizationHTTP.conflict || status == UFitRefundOrganizationHTTP.badRequest {
                do {try journal.resolve(); self.pending = nil; isStale = status == UFitRefundOrganizationHTTP.conflict; message = isStale ? UFitRefundOrganizationCopy.changed : error.localizedDescription}
                catch {localFailed = true; message = UFitRefundReviewCopy.localFailure}
            } else {handle(error, uncertain: true)}
        }
    }
    func verify() async {
        guard isCurrent, !isBusy, let pending else {return}; isBusy = true; canRetry = false; let request = generation
        defer {if request == generation {isBusy = false}}
        do {
            let result = try await session.api.refundProofReviewReceipt(reference: reference, request: pending)
            guard request == generation, isCurrent else {return}; try accept(result)
        } catch {
            guard request == generation, isCurrent else {return}
            if case UFitAPIError.requestFailed(_, _, let code) = error, code == UFitRefundReviewRules.missingReceipt {canRetry = true; message = UFitRefundReviewCopy.notRecorded}
            else {handle(error, uncertain: true)}
        }
    }
    func compare() async {
        guard isCurrent, !isBusy else {return}; isBusy = true; let request = generation
        defer {if request == generation {isBusy = false}}
        do {
            let current = try await session.api.fetchRefundOrganization(scope: .administrator, reference: reference)
            guard request == generation, isCurrent else {return}; comparison = current
            if localFailed {try journal.archiveUnreadable(); localFailed = false; message = UFitRefundOrganizationCopy.localRecovered; isStale = true}
            if !canUseVersion {message = UFitRefundReviewCopy.noLongerReviewable}
        } catch {if request == generation, isCurrent {handle(error, uncertain: false)}}
    }
    func useVersion() {guard isCurrent, !isBusy, pending == nil, canUseVersion, let comparison else {return}; document = comparison; self.comparison = nil; isStale = false; message = nil}
    private func restore(_ command: UFitRefundProofReviewRequest) {decision = command.decision; reason = command.reason; verificationReference = command.verificationReference ?? String()}
    private func accept(_ result: UFitRefundProofReviewResultDTO) throws {try journal.resolve(); pending = nil; document = result.document; isComplete = true; message = nil}
    private func fieldError(_ text: String, maximum: Int) -> String? {
        let value = UFitServerTextInput.trimmed(text)
        if value.isEmpty {return UFitRefundOrganizationCopy.required}
        return value.utf16.count > maximum ? UFitRefundOrganizationCopy.tooLong(maximum) : nil
    }
    private func handle(_ error: Error, uncertain: Bool) {
        if UFitRefundRecoveryFailure.revoked(error) || UFitRefundRecoveryFailure.missing(error) {
            pending = nil; decision = nil; reason = String(); verificationReference = String(); comparison = nil; try? journal.resolve(); localFailed = true
            hasAccess = false
            message = UFitRefundRecoveryFailure.message(error)
        } else {message = uncertain ? UFitRefundOrganizationCopy.uncertain : error.localizedDescription}
    }
}
