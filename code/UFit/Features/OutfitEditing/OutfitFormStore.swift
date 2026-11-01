import Foundation
import Observation

@MainActor @Observable
final class UFitOutfitFormStore {
    let collection: UFitManagedOutfitsStore
    let scope: UFitOutfitScope
    private(set) var original: UFitManagedOutfit?
    var draft = UFitOutfitDraft() { didSet { if !isBusy { errors = [:]; message = nil } } }
    private(set) var metadata: UFitOutfitMetadata?
    private(set) var errors: [UFitOutfitField: String] = [:]
    private(set) var isLoading = false
    private(set) var isBusy = false
    private(set) var hasPrepared = false
    private(set) var message: String?
    private enum Attempt { case idle, sending(UFitOutfitPendingCreation), recovery(UFitOutfitPendingCreation) }
    private var attempt = Attempt.idle
    @ObservationIgnored private var baseline = UFitOutfitDraft()
    @ObservationIgnored private let journal: UFitOutfitCreationJournal
    @ObservationIgnored private var photoTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var photoPayloads: [UUID: Data] = [:]
    @ObservationIgnored private var photoLoaders: [UUID: () async throws -> Data] = [:]
    private enum Copy {
        static let invalid = String(localized: "Corrigez les champs indiqués avant l’enregistrement.")
        static let photoLimit = String(localized: "Une tenue peut contenir au plus 12 photos.")
        static let photoUnavailable = String(localized: "Cette photo n’est plus disponible. Retirez-la et choisissez-la à nouveau.")
    }
    init(collection: UFitManagedOutfitsStore, original: UFitManagedOutfit?) throws {
        guard collection.access == .author, let scope = collection.scope, let userID = collection.session.user?.id,
              collection.isCurrentAccount, original == nil || (original?.scope == scope && original?.status.canEdit == true) else { throw UFitOutfitContractError.draft }
        self.collection = collection; self.scope = scope; self.original = original
        journal = .init(userID: userID, scope: scope)
        if original == nil, let pending = try journal.read() { attempt = .recovery(pending) }
    }
    var isNew: Bool { original == nil }
    var pendingCreation: UFitOutfitPendingCreation? { switch attempt { case .idle: nil; case .sending(let value), .recovery(let value): value } }
    var needsCreationRecovery: Bool { if case .recovery = attempt { true } else { false } }
    var hasChanges: Bool {
        guard draft != baseline else { return false }
        guard let original, let metadata else { return true }
        do {
            let before = try UFitOutfitWriteRequest(draft: baseline, tags: metadata.tags, scope: scope, requestID: nil, editing: original.revision)
            let after = try UFitOutfitWriteRequest(draft: draft, tags: metadata.tags, scope: scope, requestID: nil, editing: original.revision)
            return before != after
        } catch { return true }
    }
    func prepare() async {
        guard !isLoading, !isBusy, collection.isCurrentAccount else { return }
        isLoading = true; message = nil
        defer { isLoading = false }
        do {
            async let registry = collection.client.fetchOutfitMetadata()
            let fresh: UFitManagedOutfit?
            if let original, !hasPrepared { fresh = try await collection.client.fetchManagedOutfit(id: original.id, scope: scope) }
            else { fresh = original }
            let result = try await registry
            guard collection.isCurrentAccount else { return }
            metadata = result
            if !hasPrepared {
                if let fresh {
                    guard fresh.status.canEdit else { throw UFitOutfitContractError.draft }
                    draft = fresh.draft(); original = fresh
                }
                baseline = draft; hasPrepared = true
            }
        } catch { if collection.isCurrentAccount { message = error.localizedDescription } }
    }
    func save() async -> UFitManagedOutfit? {
        guard !isBusy, !isLoading, hasPrepared, pendingCreation == nil, hasChanges, collection.isCurrentAccount, let metadata else { return nil }
        errors = UFitOutfitDraftValidation.draft(draft, tags: metadata.tags)
        guard errors.isEmpty else { message = Copy.invalid; return nil }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            let request = try UFitOutfitWriteRequest(draft: draft, tags: metadata.tags, scope: scope, requestID: isNew ? UUID() : nil, editing: original?.revision)
            if isNew {
                let pending = UFitOutfitPendingCreation(request: request, draft: draft, metadata: metadata)
                try journal.record(pending); attempt = .sending(pending)
            }
            do { return try accept(await collection.client.writeOutfit(request, editingID: original?.id, scope: scope)) }
            catch {
                if isNew, let api = error as? UFitAPIError, api.isDefinitiveOutfitCreationFailure { try journal.resolve(); attempt = .idle }
                throw error
            }
        } catch {
            if let pending = pendingCreation { attempt = .recovery(pending) }
            if collection.isCurrentAccount { message = error.localizedDescription }; return nil
        }
    }
    func resumeCreation() async -> UFitManagedOutfit? {
        guard !isBusy, let pending = pendingCreation, let requestID = pending.request.requestId, collection.isCurrentAccount else { return nil }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            let result: UFitManagedOutfit
            do { result = try await collection.client.recoverOutfitCreation(scope: scope, requestID: requestID) }
            catch let error as UFitAPIError where error.isMissingOutfitResource {
                do { result = try await collection.client.writeOutfit(pending.request, editingID: nil, scope: scope) }
                catch let error as UFitAPIError where error.isDefinitiveOutfitCreationFailure {
                    try await restoreRejectedCreation(pending)
                    if collection.isCurrentAccount { message = error.localizedDescription }; return nil
                }
            }
            return try accept(result)
        } catch { if collection.isCurrentAccount { message = error.localizedDescription }; return nil }
    }
    private func restoreRejectedCreation(_ pending: UFitOutfitPendingCreation) async throws {
        let fresh = try await collection.client.fetchOutfitMetadata()
        var restored = pending.draft
        for index in restored.photos.indices {
            guard collection.isCurrentAccount, let url = restored.photos[index].url else { throw CancellationError() }
            do {
                let photo = try await collection.client.fetchOwnedOutfitPhoto(scope: scope, url: url)
                restored.photos[index].source = photo.displayUrl; restored.photos[index].transfer = .ready
            } catch let error as UFitAPIError where error.isMissingOutfitResource {
                restored.photos[index].source = nil; restored.photos[index].transfer = .failed(Copy.photoUnavailable)
            }
        }
        guard collection.isCurrentAccount else { throw CancellationError() }
        try journal.resolve()
        metadata = fresh; baseline = UFitOutfitDraft(); draft = restored; hasPrepared = true; attempt = .idle
    }
    private func accept(_ result: UFitManagedOutfit) throws -> UFitManagedOutfit? {
        guard collection.isCurrentAccount else { return nil }
        if isNew { try journal.resolve(); attempt = .idle }
        collection.receive(result); return result
    }
    func renewPhotoSource(_ id: UUID) async throws -> String {
        guard collection.isCurrentAccount, let photo = draft.photos.first(where: { $0.id == id }), let url = photo.url else { throw CancellationError() }
        let refreshed = try await collection.client.fetchOwnedOutfitPhoto(scope: scope, url: url)
        guard collection.isCurrentAccount, draft.photos.contains(where: { $0.id == id && $0.url == url }) else { throw CancellationError() }
        return refreshed.displayUrl
    }
    func addPhoto(loader: @escaping () async throws -> Data) {
        guard !isBusy, collection.isCurrentAccount else { return }
        guard draft.photos.count < UFitOutfitInput.photosMax else { message = Copy.photoLimit; return }
        let id = UUID()
        draft.photos.append(.init(id: id, serverID: nil, source: nil, url: nil, transfer: .uploading))
        photoLoaders[id] = loader; sendPhoto(id)
    }
    func retryPhoto(_ id: UUID) {
        guard !isBusy, collection.isCurrentAccount, draft.photos.first(where: { $0.id == id })?.canRetryUpload == true else { return }
        updatePhoto(id) { $0.transfer = .uploading }; sendPhoto(id)
    }
    func removePhoto(_ id: UUID) {
        guard !isBusy else { return }
        photoTasks[id]?.cancel(); photoTasks[id] = nil; photoPayloads[id] = nil; photoLoaders[id] = nil
        draft.photos.removeAll { $0.id == id }
    }
    func cancelPhotoUploads() {
        photoTasks.values.forEach { $0.cancel() }; photoTasks = [:]; photoPayloads = [:]; photoLoaders = [:]
    }
    private func updatePhoto(_ id: UUID, change: (inout UFitOutfitPhotoDraft) -> Void) {
        guard collection.isCurrentAccount, let index = draft.photos.firstIndex(where: { $0.id == id }) else { return }
        change(&draft.photos[index])
    }
    private func sendPhoto(_ id: UUID) {
        guard photoTasks[id] == nil else { return }
        photoTasks[id] = Task { [weak self] in
            guard let self else { return }
            defer { self.photoTasks[id] = nil }
            do {
                let jpeg: Data
                if let payload = self.photoPayloads[id] { jpeg = payload }
                else {
                    guard let loader = self.photoLoaders[id] else { throw UFitPhotoError.invalidImage }
                    let bytes = try await loader(); try Task.checkCancellation()
                    guard self.collection.isCurrentAccount else { throw CancellationError() }
                    jpeg = try UFitPhotoEncoding.jpeg(bytes); self.photoPayloads[id] = jpeg
                    self.updatePhoto(id) { $0.previewData = jpeg }
                }
                guard self.collection.isCurrentAccount else { throw CancellationError() }
                let photo = try await self.collection.client.uploadOutfitPhoto(scope: self.scope, requestID: id, jpeg: jpeg)
                try Task.checkCancellation()
                self.updatePhoto(id) { $0.url = photo.url; $0.source = photo.displayUrl; $0.transfer = .ready }
                self.photoPayloads[id] = nil; self.photoLoaders[id] = nil
            } catch { if !Task.isCancelled { self.updatePhoto(id) { $0.transfer = .failed(error.localizedDescription) } } }
        }
    }
}
