import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor @Observable
final class UFitProfileImageStore {
    enum Activity { case idle, importing, uploading, saving, checking }
    let scope: UFitProfileImageScope
    let accountID: String?
    private(set) var document: UFitProfileImageDocument?
    private(set) var previewData: Data?
    private(set) var wantsRemoval = false
    private(set) var activity: Activity = .idle
    private(set) var isLoading = false
    private(set) var hasConflict = false
    private(set) var message: String?
    private(set) var pending: UFitProfileImageCommand?
    private(set) var received = false
    private(set) var mayRetryCommand = false
    private(set) var uploadFailed = false
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private var uploadRequestID = UUID()
    @ObservationIgnored private var uploaded: UFitProfileImage?

    init(scope: UFitProfileImageScope, session: UFitSessionStore) {
        self.scope = scope; self.session = session; accountID = session.user?.id
    }
    var hasAccess: Bool { accountID != nil && session.user?.id == accountID && session.isSignedIn }
    var isBusy: Bool { activity != .idle }
    var hasChanges: Bool { previewData != nil || wantsRemoval }
    var canChoose: Bool { hasAccess && !isBusy && !isLoading && pending == nil && document != nil }
    var canSave: Bool { hasAccess && hasChanges && !isBusy && !isLoading && document != nil }
    var actionTitle: String {
        if received || pending != nil && !mayRetryCommand { return UFitProfileImageCopy.verify }
        if pending != nil { return UFitProfileImageCopy.retrySave }
        if uploadFailed { return UFitProfileImageCopy.retrySave }
        if wantsRemoval { return UFitProfileImageCopy.confirmRemoval }
        if hasConflict { return UFitProfileImageCopy.useMine }
        return UFitProfileImageCopy.save
    }
    var activityLabel: String {
        switch activity {
        case .idle: UFitProfileImageCopy.save
        case .importing: UFitProfileImageCopy.reading
        case .uploading: UFitProfileImageCopy.uploading
        case .saving: UFitProfileImageCopy.saving
        case .checking: UFitProfileImageCopy.checking
        }
    }
    func refresh() async {
        guard hasAccess, !isBusy, !isLoading else { return }
        isLoading = true
        if pending == nil { message = nil }
        defer { isLoading = false }
        do {
            let current = try await session.api.fetchProfileImage(scope: scope)
            guard hasAccess else { return }
            try accept(current)
            if let pending { reconcile(current, command: pending) }
            else { message = nil }
        } catch { if hasAccess { message = pending == nil ? UFitProfileImageCopy.failure(error) : received ? UFitProfileImageCopy.accepted : UFitProfileImageCopy.uncertain } }
    }
    func choose(_ item: PhotosPickerItem) async {
        guard canChoose else { return }
        activity = .importing; message = nil
        defer { activity = .idle }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw UFitPhotoError.invalidImage }
            guard hasAccess else { return }
            let jpeg = try UFitPhotoEncoding.jpeg(data)
            previewData = jpeg; wantsRemoval = false; uploaded = nil; uploadFailed = false; uploadRequestID = UUID()
        } catch { if hasAccess { message = UFitProfileImageCopy.failure(error) } }
    }
    func remove() {
        guard canChoose else { return }
        message = nil
        guard document?.image != nil else { clearDraft(); return }
        previewData = nil; uploaded = nil; uploadFailed = false; uploadRequestID = UUID()
        wantsRemoval = true
    }
    func abandonPreview() {
        // An uncertain command is retained for a read or idempotent retry on reopening.
        guard pending == nil else { return }
        clearDraft()
    }
    func save() async {
        guard canSave, let document else { return }
        if received || pending != nil && !mayRetryCommand { await refresh(); return }
        message = nil
        if pending == nil {
            if !wantsRemoval, uploaded == nil, let previewData {
                uploadFailed = false; activity = .uploading
                do {
                    let image = try await session.api.uploadProfileImage(scope: scope, requestID: uploadRequestID, jpeg: previewData)
                    guard hasAccess else { activity = .idle; return }
                    uploaded = image
                } catch { activity = .idle; if hasAccess { uploadFailed = true; message = UFitProfileImageCopy.uploadFailure(error) }; return }
            }
            guard wantsRemoval || uploaded?.id != nil else { activity = .idle; return }
            pending = UFitProfileImageCommand(requestId: UUID(), expectedVersion: document.version, assetId: wantsRemoval ? nil : uploaded?.id)
            hasConflict = false
        }
        guard let command = pending else { activity = .idle; return }
        mayRetryCommand = false; activity = .saving
        defer { activity = .idle }
        do {
            _ = try await session.api.selectProfileImage(scope: scope, command: command)
            guard hasAccess else { return }
            received = true
        } catch {
            guard hasAccess else { return }
            if let failure = error as? UFitAPIError, case .requestFailed(let status, _, let code) = failure,
               UFitProfileImageHTTP.definitiveRejections.contains(status) {
                pending = nil; received = false
                if status == UFitProfileImageHTTP.conflict && code == UFitProfileImageHTTP.versionChanged {
                    await readAfterCommand(command, rejected: true)
                } else { message = UFitProfileImageCopy.failure(error) }
                return
            }
            message = UFitProfileImageCopy.uncertain
        }
        await readAfterCommand(command, rejected: false)
    }
    private func readAfterCommand(_ command: UFitProfileImageCommand, rejected: Bool) async {
        activity = .checking
        do {
            let current = try await session.api.fetchProfileImage(scope: scope)
            guard hasAccess else { return }
            try accept(current)
            if rejected {
                hasConflict = true; message = UFitProfileImageCopy.conflict
            } else { reconcile(current, command: command) }
        } catch { if hasAccess { message = rejected ? UFitProfileImageCopy.currentUnavailable : received ? UFitProfileImageCopy.accepted : UFitProfileImageCopy.uncertain } }
    }
    private func accept(_ current: UFitProfileImageDocument) throws {
        if let document {
            guard current.version >= document.version else { throw UFitPhotoError.invalidResponse }
            if pending == nil && hasChanges && current.version > document.version { hasConflict = true }
        }
        document = current
    }
    private func reconcile(_ current: UFitProfileImageDocument, command: UFitProfileImageCommand) {
        guard current.version > command.expectedVersion else {
            mayRetryCommand = !received && current.version == command.expectedVersion
            message = received ? UFitProfileImageCopy.accepted : UFitProfileImageCopy.unchanged
            return
        }
        let matches = command.assetId == nil ? current.image == nil : current.image?.id == command.assetId
        guard matches else {
            pending = nil; received = false; hasConflict = true; message = UFitProfileImageCopy.conflict
            return
        }
        let removed = command.assetId == nil
        clearDraft(); message = removed ? UFitProfileImageCopy.removed : UFitProfileImageCopy.saved
    }
    private func clearDraft() {
        previewData = nil; wantsRemoval = false; uploaded = nil; uploadFailed = false; uploadRequestID = UUID()
        pending = nil; received = false; mayRetryCommand = false; hasConflict = false
    }
}
