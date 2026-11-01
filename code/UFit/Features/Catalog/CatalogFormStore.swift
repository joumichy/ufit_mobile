import Foundation
import Observation

@MainActor @Observable
final class UFitCatalogFormStore {
    let catalog: UFitCatalogStore
    private(set) var original: UFitManagedProduct?
    var draft = UFitCatalogProductDraft() { didSet { if !isBusy { errors = [:]; message = nil } } }
    private(set) var currencies: [UFitCatalogCurrency] = []
    private(set) var errors: [UFitCatalogField: String] = [:]
    private(set) var isLoading = false
    private(set) var isBusy = false
    private(set) var hasPrepared = false
    private(set) var message: String?
    private enum CreationAttempt { case idle, inFlight(UFitCatalogWriteRequest), recovery(UFitCatalogWriteRequest) }
    private var creationAttempt = CreationAttempt.idle
    @ObservationIgnored private var baseline = UFitCatalogProductDraft()
    @ObservationIgnored private let journal: UFitCatalogCreationJournal
    @ObservationIgnored private var photoTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var photoPayloads: [UUID: Data] = [:]
    @ObservationIgnored private var photoLoaders: [UUID: () async throws -> Data] = [:]
    private enum Copy {
        static let invalid = String(localized: "Corrigez les champs indiqués avant l’enregistrement.")
        static let photosLimit = String(localized: "Un produit peut contenir au plus 12 photos.")
        static let photoUnavailable = String(localized: "Cette photo n’est plus disponible. Retirez-la et choisissez-la à nouveau.")
    }
    init(catalog: UFitCatalogStore, original: UFitManagedProduct?) throws {
        guard catalog.access == .member, let brandID = catalog.brandID, let userID = catalog.session.user?.id, catalog.isCurrentAccount,
              original == nil || (original?.product.brandId == brandID && original?.product.status.canEdit == true) else { throw UFitCatalogContractError.draft }
        self.catalog = catalog; self.original = original
        journal = UFitCatalogCreationJournal(userID: userID, brandID: brandID)
        if original == nil, let pending = try journal.read() { creationAttempt = .recovery(pending) }
    }
    var isNew: Bool { original == nil }
    var pendingCreation: UFitCatalogWriteRequest? {
        switch creationAttempt { case .idle: nil; case .inFlight(let request), .recovery(let request): request }
    }
    var needsCreationRecovery: Bool { if case .recovery = creationAttempt { true } else { false } }
    var hasChanges: Bool {
        guard draft != baseline else { return false }
        guard let original, let currency = currencies.first(where: { $0.code == draft.currency }),
              let beforeCurrency = currencies.first(where: { $0.code == baseline.currency }) else { return true }
        do {
            let before = try UFitCatalogWriteRequest(draft: baseline, currency: beforeCurrency, creatingBrandID: nil, requestID: nil, editing: original.revision)
            let after = try UFitCatalogWriteRequest(draft: draft, currency: currency, creatingBrandID: nil, requestID: nil, editing: original.revision)
            return before != after
        } catch { return true }
    }
    func prepare() async {
        guard !isLoading, !isBusy, catalog.isCurrentAccount else { return }
        isLoading = true; message = nil
        defer { isLoading = false }
        do {
            async let currenciesRequest = catalog.client.fetchCatalogCurrencies()
            let fresh: UFitManagedProduct?
            if let original, !hasPrepared { fresh = try await catalog.client.fetchManagedProduct(id: original.id, brandID: catalog.brandID) }
            else { fresh = original }
            let result = try await currenciesRequest
            guard catalog.isCurrentAccount else { return }
            currencies = result
            if !hasPrepared {
                if let fresh {
                    guard fresh.product.status.canEdit else { throw UFitCatalogContractError.stale }
                    draft = try fresh.draft(currencies: result); original = fresh
                }
                baseline = draft; hasPrepared = true
            }
        } catch { if catalog.isCurrentAccount { message = error.localizedDescription } }
    }
    func save() async -> UFitManagedProduct? {
        guard !isBusy, !isLoading, hasPrepared, pendingCreation == nil, hasChanges, catalog.isCurrentAccount,
              let brandID = catalog.brandID else { return nil }
        errors = UFitCatalogDraftValidation.product(draft, currencies: currencies)
        guard errors.isEmpty, let currency = currencies.first(where: { $0.code == draft.currency }) else { message = Copy.invalid; return nil }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            let request = try UFitCatalogWriteRequest(draft: draft, currency: currency, creatingBrandID: isNew ? brandID : nil,
                requestID: isNew ? UUID() : nil, editing: original?.revision)
            if isNew { try journal.record(request); creationAttempt = .inFlight(request) }
            do {
                let result = try await catalog.client.writeCatalogProduct(request, editingID: original?.id, brandID: brandID)
                return try accept(result)
            } catch {
                if isNew, let api = error as? UFitAPIError, api.isDefinitiveCatalogCreationFailure { try journal.resolve(); creationAttempt = .idle }
                throw error
            }
        } catch {
            if let pending = pendingCreation { creationAttempt = .recovery(pending) }
            if catalog.isCurrentAccount { message = error.localizedDescription }; return nil
        }
    }
    func resumeCreation() async -> UFitManagedProduct? {
        guard !isBusy, let pendingCreation, let requestID = pendingCreation.requestId, let brandID = catalog.brandID, catalog.isCurrentAccount else { return nil }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            let result: UFitManagedProduct
            do { result = try await catalog.client.recoverCatalogCreation(brandID: brandID, requestID: requestID) }
            catch let error as UFitAPIError where error.isMissingCatalogResource {
                do { result = try await catalog.client.writeCatalogProduct(pendingCreation, editingID: nil, brandID: brandID) }
                catch let error as UFitAPIError where error.isDefinitiveCatalogCreationFailure {
                    try await restoreRejectedCreation(pendingCreation, brandID: brandID)
                    if catalog.isCurrentAccount { message = error.localizedDescription }
                    return nil
                }
            }
            return try accept(result)
        } catch { if catalog.isCurrentAccount { message = error.localizedDescription }; return nil }
    }
    private func restoreRejectedCreation(_ request: UFitCatalogWriteRequest, brandID: String) async throws {
        let currencies = try await catalog.client.fetchCatalogCurrencies()
        var photos = [UFitCatalogPhotoDraft]()
        for image in request.images.sorted(by: { $0.position < $1.position }) {
            guard catalog.isCurrentAccount else { throw CancellationError() }
            do {
                let photo = try await catalog.client.fetchOwnedProductPhoto(brandID: brandID, url: image.url)
                photos.append(.init(id: UUID(), serverID: nil, source: photo.displayUrl, url: photo.url, kind: image.kind, transfer: .ready))
            } catch let error as UFitAPIError where error.isMissingCatalogResource {
                photos.append(.init(id: UUID(), serverID: nil, source: nil, url: image.url, kind: image.kind, transfer: .failed(Copy.photoUnavailable)))
            }
        }
        let restored = try request.creationDraft(currencies: currencies, photos: photos)
        guard catalog.isCurrentAccount else { throw CancellationError() }
        try journal.resolve()
        self.currencies = currencies; baseline = UFitCatalogProductDraft(); draft = restored
        hasPrepared = true; creationAttempt = .idle
    }
    private func accept(_ result: UFitManagedProduct) throws -> UFitManagedProduct? {
        guard catalog.isCurrentAccount else { return nil }
        if isNew { try journal.resolve(); creationAttempt = .idle }
        catalog.receive(result)
        return result
    }
    func addPhoto(loader: @escaping () async throws -> Data) {
        guard !isBusy, catalog.isCurrentAccount else { return }
        guard draft.photos.count < UFitCatalogInput.photosMax else { message = Copy.photosLimit; return }
        let id = UUID()
        draft.photos.append(.init(id: id, serverID: nil, source: nil, url: nil, kind: .product, transfer: .uploading))
        photoLoaders[id] = loader
        sendPhoto(id)
    }
    func retryPhoto(_ id: UUID) {
        guard !isBusy, catalog.isCurrentAccount, let photo = draft.photos.first(where: { $0.id == id }), photo.canRetryUpload else { return }
        updatePhoto(id) { $0.transfer = .uploading }
        sendPhoto(id)
    }
    func removePhoto(_ id: UUID) {
        guard !isBusy else { return }
        photoTasks[id]?.cancel(); photoTasks[id] = nil; photoPayloads[id] = nil; photoLoaders[id] = nil
        draft.photos.removeAll { $0.id == id }
    }
    func cancelPhotoUploads() {
        photoTasks.values.forEach { $0.cancel() }; photoTasks = [:]; photoPayloads = [:]; photoLoaders = [:]
    }
    private func updatePhoto(_ id: UUID, change: (inout UFitCatalogPhotoDraft) -> Void) {
        guard catalog.isCurrentAccount, let index = draft.photos.firstIndex(where: { $0.id == id }) else { return }
        change(&draft.photos[index])
    }
    private func sendPhoto(_ id: UUID) {
        guard photoTasks[id] == nil, let brandID = catalog.brandID else { return }
        photoTasks[id] = Task { [weak self] in
            guard let self else { return }
            defer { self.photoTasks[id] = nil }
            do {
                let jpeg: Data
                if let payload = self.photoPayloads[id] { jpeg = payload }
                else {
                    guard let loader = self.photoLoaders[id] else { throw UFitProductPhotoError.invalidImage }
                    let bytes = try await loader(); try Task.checkCancellation()
                    jpeg = try UFitCatalogPhotoEncoding.jpeg(bytes)
                    self.photoPayloads[id] = jpeg
                    self.updatePhoto(id) { $0.previewData = jpeg }
                }
                let photo = try await self.catalog.client.uploadProductPhoto(brandID: brandID, requestID: id, jpeg: jpeg)
                try Task.checkCancellation()
                self.updatePhoto(id) { $0.url = photo.url; $0.source = photo.displayUrl; $0.transfer = .ready }
                self.photoPayloads[id] = nil; self.photoLoaders[id] = nil
            } catch {
                if !Task.isCancelled { self.updatePhoto(id) { $0.transfer = .failed(error.localizedDescription) } }
            }
        }
    }
}

@MainActor @Observable
final class UFitCatalogStockStore {
    let product: UFitCatalogProductStore
    let revision: UFitCatalogRevision
    let variant: UFitManagedProduct.Variant
    var quantity: String { didSet { if !isBusy { error = nil; message = nil } } }
    private(set) var isBusy = false
    private(set) var error: String?
    private(set) var message: String?
    init(product: UFitCatalogProductStore, variant: UFitManagedProduct.Variant) {
        self.product = product; self.variant = variant; revision = product.document.revision; quantity = String(variant.stockQuantity)
    }
    var hasChanges: Bool { UFitCatalogInput.integer(quantity) != variant.stockQuantity }
    func save() async -> Bool {
        guard !isBusy, hasChanges, product.catalog.isCurrentAccount else { return false }
        guard let amount = UFitCatalogInput.integer(quantity) else { error = UFitCatalogDraftValidation.Copy.stock; return false }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            let result = try await product.catalog.client.updateCatalogStock(revision, variantID: variant.id, expectedQuantity: variant.stockQuantity, quantity: amount)
            guard product.catalog.isCurrentAccount else { return false }
            try product.receive(result); return true
        } catch { if product.catalog.isCurrentAccount { message = error.localizedDescription }; return false }
    }
}
