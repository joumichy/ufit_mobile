import Foundation
import Observation

@MainActor @Observable
final class UFitRefundOrganizationStore: Identifiable {
    let id = UUID()
    let scope: UFitRefundOrganizationScope
    let reference: UFitRefundRecoveryReference
    private(set) var document: UFitRefundOrganizationDocumentDTO?
    private(set) var comparison: UFitRefundOrganizationDocumentDTO?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var isEditing = false
    private(set) var isStale = false
    private(set) var message: String?
    private(set) var messageIsError = false
    private(set) var errors = [UFitRefundOrganizationField: String]()
    private(set) var pending: UFitRefundOrganizationRequest?
    private(set) var canRetryExact = false
    private(set) var hasProofRequest = false
    private(set) var hasReviewRequest = false
    private(set) var openingProofIDs = Set<String>()
    private(set) var proofDownloadErrors = [String: String]()
    private(set) var proofHistory = [UFitRefundProofDTO]()
    private(set) var historyCursor: String?
    private(set) var isLoadingHistory = false
    private(set) var historyMessage: String?
    var previewURL: URL?
    @ObservationIgnored private var previewFile: URL?
    private(set) var localRecordFailed = false
    var draft = UFitRefundOrganizationDraft() {didSet {if draft != oldValue && !isSaving {errors = [:]; if !isStale && pending == nil {message = nil}}}}
    @ObservationIgnored let session: UFitSessionStore
    @ObservationIgnored private let ownerID: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var previewGeneration = UUID()
    @ObservationIgnored private var editingVersion = Int.zero
    @ObservationIgnored private var editingAction: UFitRefundOrganizationAction?
    @ObservationIgnored private var original = UFitRefundOrganizationDraft()
    @ObservationIgnored private var didReadJournal = false
    init(scope: UFitRefundOrganizationScope, reference: UFitRefundRecoveryReference, session: UFitSessionStore) {self.scope = scope; self.reference = reference; self.session = session; ownerID = session.user?.id}
    var isCurrentAccount: Bool {ownerID != nil && ownerID == session.user?.id && (scope != .administrator || session.user?.canAdminister == true)}
    var action: UFitRefundOrganizationAction? {editingAction}
    var hasChanges: Bool {isEditing && draft != original}
    var isUncertain: Bool {pending != nil}
    var isOpeningProof: Bool {document?.proof.map {openingProofIDs.contains($0.id)} ?? false}
    var proofMessage: String? {document?.proof.flatMap {proofDownloadErrors[$0.id]}}
    var journal: UFitRefundOrganizationJournal? {ownerID.map {.init(actorID: $0, scope: scope, reference: reference)}}
    func cancelLoading() {generation = UUID(); previewGeneration = UUID(); isLoading = false; isSaving = false; openingProofIDs = []; isLoadingHistory = false}
    func load() async {
        guard isCurrentAccount, !isLoading, !isSaving else {return}
        let request = generation; isLoading = true; message = nil; messageIsError = false
        defer {if generation == request {isLoading = false}}
        do {
            let current = try await session.api.fetchRefundOrganization(scope: scope, reference: reference)
            guard generation == request, isCurrentAccount else {return}
            if isEditing && (current.organization?.version ?? .zero) != editingVersion {comparison = current; isStale = true} else {receive(current)}
            if !didReadJournal {
                didReadJournal = true
                do {
                    pending = try journal?.read()
                    if let pending {draft = pending.draft; original = draft; editingVersion = pending.expectedVersion; editingAction = pending.action; isEditing = true}
                } catch {localRecordFailed = true; messageIsError = true; message = UFitRefundOrganizationFailure.localRecord.localizedDescription}
            }
            if scope == .brand, let ownerID {
                do {hasProofRequest = try UFitRefundProofJournal(actorID: ownerID, reference: reference).read() != nil}
                catch {hasProofRequest = true}
            }
            if scope == .administrator, let ownerID {
                do {hasReviewRequest = try UFitRefundProofReviewJournal(actorID: ownerID, reference: reference).read() != nil}
                catch {hasReviewRequest = true}
            }
            if pending != nil {await verifyPending()}
        } catch {if generation == request, isCurrentAccount {failure(error)}}
    }
    func edit() {
        guard isCurrentAccount, !isLoading, !isSaving, !localRecordFailed, pending == nil, let document, let action = document.actions.first else {return}
        editingAction = action; editingVersion = document.organization?.version ?? .zero
        draft = .init(methodLabel: document.organization?.methodLabel ?? String(), instructions: document.organization?.instructions ?? String(), details: document.organization?.customerDetails ?? String())
        original = draft; isEditing = true; isStale = false; comparison = nil; message = nil; errors = [:]
    }
    func cancelEdit() {guard !isSaving, pending == nil else {return}; if let comparison {receive(comparison)}; isEditing = false; editingAction = nil; comparison = nil; isStale = false; draft = .init(); errors = [:]; message = nil}
    func useComparedVersion() {
        guard let comparison, let editingAction, comparison.actions.contains(editingAction), pending == nil, !isSaving else {return}
        receive(comparison); editingVersion = comparison.organization?.version ?? .zero; self.comparison = nil; isStale = false; message = nil
    }
    func save() async {
        guard isCurrentAccount, !isSaving, !isLoading, !isStale, !localRecordFailed, pending == nil, let action else {return}
        errors = UFitRefundOrganizationRules.errors(draft, action: action)
        guard errors.isEmpty else {messageIsError = true; message = UFitRefundOrganizationCopy.invalid; return}
        do {
            let command = try UFitRefundOrganizationRequest(action: action, version: editingVersion, draft: draft)
            guard let journal else {throw UFitRefundOrganizationFailure.localRecord}
            try journal.record(command); pending = command; await sendPending()
        } catch {messageIsError = true; message = error.localizedDescription}
    }
    func sendPending() async {
        guard isCurrentAccount, !isSaving, let pending else {return}
        let request = generation; isSaving = true; canRetryExact = false; message = nil; messageIsError = false
        defer {if generation == request {isSaving = false}}
        do {
            let result = try await session.api.applyRefundOrganization(scope: scope, reference: reference, request: pending)
            guard generation == request, isCurrentAccount else {return}; try accepted(result)
        } catch {
            guard generation == request, isCurrentAccount else {return}
            draft = pending.draft; messageIsError = true
            if case UFitAPIError.requestFailed(let status, _, _) = error, status == UFitRefundOrganizationHTTP.conflict || status == UFitRefundOrganizationHTTP.badRequest {
                do {try journal?.resolve(); self.pending = nil} catch {message = error.localizedDescription; return}
                isStale = status == UFitRefundOrganizationHTTP.conflict
                message = isStale ? UFitRefundOrganizationCopy.changed : error.localizedDescription
            } else if UFitRefundRecoveryFailure.revoked(error) || UFitRefundRecoveryFailure.missing(error) {failure(error)}
            else {message = UFitRefundOrganizationCopy.uncertain}
        }
    }
    func verifyPending() async {
        guard isCurrentAccount, !isSaving, let pending else {return}
        let request = generation; isSaving = true; canRetryExact = false
        defer {if generation == request {isSaving = false}}
        do {
            let result = try await session.api.refundOrganizationReceipt(scope: scope, reference: reference, request: pending)
            guard generation == request, isCurrentAccount else {return}; try accepted(result)
        } catch {
            guard generation == request, isCurrentAccount else {return}
            draft = pending.draft; messageIsError = true
            if case UFitAPIError.requestFailed(_, _, let code) = error, code == UFitRefundOrganizationHTTP.missingReceipt {canRetryExact = true; messageIsError = false; message = UFitRefundOrganizationCopy.notRecorded}
            else if UFitRefundRecoveryFailure.revoked(error) || UFitRefundRecoveryFailure.missing(error) {failure(error)}
            else {message = UFitRefundOrganizationCopy.uncertain}
        }
    }
    func recoverLocalRecord() async {
        guard isCurrentAccount, localRecordFailed, !isLoading, !isSaving else {return}
        let request = generation; isLoading = true
        defer {if generation == request {isLoading = false}}
        do {
            let current = try await session.api.fetchRefundOrganization(scope: scope, reference: reference)
            guard generation == request, isCurrentAccount else {return}
            guard let journal else {throw UFitRefundOrganizationFailure.localRecord}
            try journal.archiveUnreadable(); receive(current); localRecordFailed = false; didReadJournal = true
            messageIsError = false; message = UFitRefundOrganizationCopy.localRecovered
        } catch {if generation == request, isCurrentAccount {failure(error)}}
    }
    func loadHistory(reset: Bool) async {
        guard isCurrentAccount, !isLoadingHistory, reset || historyCursor != nil else {return}
        let request = generation; isLoadingHistory = true; historyMessage = nil
        defer {if request == generation {isLoadingHistory = false}}
        do {
            let result = try await session.api.refundProofHistory(scope: scope, reference: reference, cursor: reset ? nil : historyCursor)
            guard request == generation, isCurrentAccount else {return}
            if !reset {
                let existing = Set(proofHistory.map(\.id))
                guard result.items.allSatisfy({!existing.contains($0.id)}), result.items.first == nil || proofHistory.last == nil || result.items.first!.sequence < proofHistory.last!.sequence else {throw UFitRefundOrganizationFailure.contract}
            }
            proofHistory = reset ? result.items : proofHistory + result.items; historyCursor = result.nextCursor
        } catch {
            if request == generation, isCurrentAccount {
                if UFitRefundRecoveryFailure.revoked(error) || UFitRefundRecoveryFailure.missing(error) {failure(error)}
                else {historyMessage = error.localizedDescription}
            }
        }
    }
    func openProof(_ proof: UFitRefundProofDTO) async {
        guard isCurrentAccount, !openingProofIDs.contains(proof.id) else {return}
        openingProofIDs.insert(proof.id); proofDownloadErrors[proof.id] = nil; let request = generation
        let previewRequest = UUID(); previewGeneration = previewRequest
        defer {if request == generation {openingProofIDs.remove(proof.id)}}
        do {
            let bytes = try await session.api.downloadRefundProof(scope: scope, reference: reference, proof: proof)
            guard request == generation, previewRequest == previewGeneration, isCurrentAccount else {return}
            clearProofPreview()
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(Preview.title).appendingPathExtension(proof.file.contentType == UFitRefundProofContract.pdf ? Preview.pdf : Preview.jpeg)
            try bytes.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            try FileManager.default.setAttributes([.posixPermissions: Preview.permissions], ofItemAtPath: url.path)
            previewFile = url; previewURL = url
        } catch {
            if request == generation, isCurrentAccount {
                if UFitRefundRecoveryFailure.revoked(error) || UFitRefundRecoveryFailure.missing(error) {failure(error)}
                else {proofDownloadErrors[proof.id] = UFitRefundProofCopy.downloadFailure}
            }
        }
    }
    func clearProofPreview() {previewURL = nil; if let previewFile {try? FileManager.default.removeItem(at: previewFile.deletingLastPathComponent())}; previewFile = nil}
    private enum Preview {static let title = "Justificatif Ufit", pdf = "pdf", jpeg = "jpg", permissions = 0o600}
    private func accepted(_ result: UFitRefundOrganizationResultDTO) throws {
        receive(result.document)
        try journal?.resolve(); pending = nil; isEditing = false; editingAction = nil; comparison = nil; isStale = false; draft = .init(); errors = [:]; messageIsError = false; message = UFitRefundOrganizationCopy.saved
    }
    private func receive(_ current: UFitRefundOrganizationDocumentDTO) {
        guard document == nil || (current.organization?.version ?? .zero) >= (document?.organization?.version ?? .zero) else {return}
        document = current
    }
    private func failure(_ error: Error) {
        messageIsError = true
        if UFitRefundRecoveryFailure.revoked(error) || UFitRefundRecoveryFailure.missing(error) {
            clearProofPreview(); hasProofRequest = false; hasReviewRequest = false; document = nil; comparison = nil; draft = .init(); isEditing = false; editingAction = nil
            proofHistory = []; historyCursor = nil; proofDownloadErrors = [:]
            try? journal?.resolve(); pending = nil
        }
        message = UFitRefundRecoveryFailure.message(error)
    }
}
