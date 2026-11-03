import Foundation
import Observation

@MainActor @Observable
final class UFitRefundProofUploadStore: Identifiable {
    let id = UUID()
    let reference: UFitRefundRecoveryReference
    let amount: String
    var transferReference = String() {didSet {if pending == nil && !isBusy {referenceError = nil; message = nil}}}
    var transferredOn = String() {didSet {if pending == nil && !isBusy {dateError = nil; message = nil}}}
    private(set) var file: UFitRefundProofSelection?
    private(set) var pending: UFitRefundProofRequest?
    private(set) var isBusy = false
    private(set) var isComplete = false
    private(set) var isStale = false
    private(set) var localFailed = false
    private(set) var canRetry = false
    private(set) var message: String?
    private(set) var referenceError: String?
    private(set) var dateError: String?
    private(set) var fileError: String?
    private(set) var comparison: UFitRefundOrganizationDocumentDTO?
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let actorID: String
    @ObservationIgnored private var version: Int
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private var generation = UUID()
    init(document: UFitRefundOrganizationDocumentDTO, session: UFitSessionStore, actorID: String) {
        reference = document.summary.reference; amount = UFitMoney.format(document.summary.amount, currency: document.summary.currency)
        version = document.organization?.version ?? .zero; self.session = session; self.actorID = actorID
    }
    var isCurrent: Bool {session.user?.id == actorID}
    var hasChanges: Bool {!transferReference.isEmpty || !transferredOn.isEmpty || file != nil}
    var canUseVersion: Bool {comparison?.proof == nil && comparison?.organization?.status == .ready}
    private var journal: UFitRefundProofJournal {.init(actorID: actorID, reference: reference)}
    func cancelLoading() {generation = UUID(); isBusy = false}
    func load() async {
        guard isCurrent, !loaded else {return}; loaded = true
        do {pending = try journal.read(); if let pending {restore(pending); await verify()}}
        catch {localFailed = true; message = UFitRefundProofCopy.localFailure}
    }
    func select(_ result: Result<URL, Error>) {
        guard isCurrent, !isBusy, pending == nil, !localFailed else {return}
        do {file = try UFitRefundProofSelection(url: result.get()); fileError = nil; message = nil}
        catch {fileError = error.localizedDescription}
    }
    func save() async {
        guard isCurrent, !isBusy, !isStale, !localFailed, pending == nil else {return}
        let clean = UFitServerTextInput.trimmed(transferReference)
        referenceError = UFitServerTextInput.valid(clean, maximum: UFitRefundProofContract.referenceMaximum) ? nil : UFitRefundOrganizationCopy.tooLong(UFitRefundProofContract.referenceMaximum)
        if clean.isEmpty {referenceError = UFitRefundOrganizationCopy.required}
        let date = UFitRefundProofContract.dateValue(transferredOn)
        dateError = date == nil || date! > Date() ? UFitRefundProofCopy.dateRule : nil
        fileError = file == nil ? UFitRefundProofCopy.missingFile : nil
        guard referenceError == nil, dateError == nil, fileError == nil, let file else {message = UFitRefundOrganizationCopy.invalid; return}
        let request = UFitRefundProofRequest(requestId: UUID().uuidString.lowercased(), expectedVersion: version, transferReference: clean, transferredOn: transferredOn, file: file)
        do {try journal.write(request); pending = request; restore(request); await send()}
        catch {message = error.localizedDescription}
    }
    func send() async {
        guard isCurrent, !isBusy, let pending else {return}
        isBusy = true; canRetry = false; let request = generation
        defer {if request == generation {isBusy = false}}
        do {
            let receipt = try await session.api.uploadRefundProof(reference: reference, request: pending)
            guard request == generation, isCurrent else {return}; try accept(receipt)
        } catch {
            guard request == generation, isCurrent else {return}
            if case UFitAPIError.requestFailed(let status, _, _) = error, status == UFitRefundOrganizationHTTP.conflict || status == UFitRefundOrganizationHTTP.badRequest {
                do {try journal.resolve(); self.pending = nil; isStale = status == UFitRefundOrganizationHTTP.conflict; message = isStale ? UFitRefundOrganizationCopy.changed : error.localizedDescription}
                catch {message = UFitRefundProofCopy.localFailure}
            } else {handle(error, uncertain: true)}
        }
    }
    func verify() async {
        guard isCurrent, !isBusy, let pending else {return}
        isBusy = true; canRetry = false; let request = generation
        defer {if request == generation {isBusy = false}}
        do {
            let receipt = try await session.api.refundProofReceipt(reference: reference, request: pending)
            guard request == generation, isCurrent else {return}; try accept(receipt)
        } catch {
            guard request == generation, isCurrent else {return}
            if case UFitAPIError.requestFailed(_, _, let code) = error, code == UFitRefundProofContract.missingReceipt {canRetry = true; message = UFitRefundProofCopy.notSubmitted}
            else {handle(error, uncertain: true)}
        }
    }
    func compare() async {
        guard isCurrent, !isBusy else {return}; isBusy = true; let request = generation
        defer {if request == generation {isBusy = false}}
        do {
            let current = try await session.api.fetchRefundOrganization(scope: .brand, reference: reference)
            guard request == generation, isCurrent else {return}
            comparison = current
            if localFailed {try journal.archiveUnreadable(); localFailed = false; message = UFitRefundOrganizationCopy.localRecovered}
            if current.proof != nil {isComplete = true}
        } catch {if request == generation, isCurrent {handle(error, uncertain: false)}}
    }
    func useVersion() {guard isCurrent, canUseVersion, let version = comparison?.organization?.version, pending == nil, !isBusy else {return}; self.version = version; isStale = false; comparison = nil; message = nil}
    private func restore(_ request: UFitRefundProofRequest) {transferReference = request.transferReference; transferredOn = request.transferredOn; file = request.file; version = request.expectedVersion}
    private func accept(_ receipt: UFitRefundProofReceiptDTO) throws {
        if receipt.state == .submitted {try journal.resolve(); pending = nil; isComplete = true; message = nil}
        else {canRetry = true; message = UFitRefundProofCopy.notSubmitted}
    }
    private func handle(_ error: Error, uncertain: Bool) {
        if UFitRefundRecoveryFailure.revoked(error) || UFitRefundRecoveryFailure.missing(error) {
            file = nil; pending = nil; transferReference = String(); transferredOn = String(); comparison = nil; try? journal.resolve(); localFailed = true
            message = UFitRefundRecoveryFailure.message(error)
        } else {message = uncertain ? UFitRefundProofCopy.uncertain : error.localizedDescription}
    }
}
