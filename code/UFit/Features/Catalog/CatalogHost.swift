import SwiftUI
import PhotosUI

struct UFitCatalogHost: View {
    let store: UFitCatalogStore
    let onBack: () -> Void
    let onOpen: (UFitCatalogProductStore) -> Void
    let onCreate: (UFitCatalogStore) -> Void
    var body: some View {
        UFitCatalogListContent(title: store.title, subtitle: store.subtitle, access: store.access, rows: store.rows,
            selectedStatus: store.selectedStatus, hasLoaded: store.hasLoaded, isLoading: store.isLoading, isLoadingMore: store.isLoadingMore,
            hasMore: store.nextCursor != nil, busyIDs: store.busyIDs, message: store.message, onBack: onBack,
            onSelectStatus: { status in Task { await store.filter(status) } }, onRefresh: { await store.load() },
            onMore: { Task { await store.more() } }, onOpen: { id in Task { if let product = await store.open(id) { onOpen(product) } } },
            onCreate: { onCreate(store) })
            .task { await store.load() }
            .onDisappear { store.cancelOpening() }
    }
}
struct UFitCatalogProductHost: View {
    let store: UFitCatalogProductStore
    let onBack: () -> Void
    let onEdit: (UFitCatalogProductStore) -> Void
    let onStock: (UFitCatalogProductStore, String) -> Void
    var body: some View {
        UFitCatalogProductContent(product: store.document.presentation(), access: store.catalog.access, isLoading: store.isLoading,
            isMutatingProduct: store.isMutating, message: store.message, onBack: onBack, onRefresh: { Task { await store.load() } },
            onEdit: { onEdit(store) }, onStock: { onStock(store, $0) },
            onPublish: { revision in Task { await store.mutate(revision, action: .publish) } },
            onWithdraw: { revision in Task { await store.mutate(revision, action: .withdraw) } },
            onArchive: { revision in Task { await store.mutate(revision, action: .archive) } },
            onRestore: { revision in Task { await store.mutate(revision, action: .restore) } })
    }
}
struct UFitCatalogFormHost: View {
    @Bindable var store: UFitCatalogFormStore
    let onBack: () -> Void
    let onSaved: (UFitManagedProduct) -> Void
    @State private var showingPhotos = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    private enum Selection { static let minimumSlots = 1 }
    var body: some View {
        Group {
            if store.needsCreationRecovery, let pending = store.pendingCreation {
                UFitCatalogCreationRecoveryContent(productName: pending.name, isBusy: store.isBusy, message: store.message, onBack: onBack,
                    onResume: { Task { if let product = await store.resumeCreation() { onSaved(product) } } })
            } else if !store.hasPrepared {
                UFitCatalogPreparationContent(isLoading: store.isLoading, message: store.message, onBack: onBack, onRetry: { Task { await store.prepare() } })
            } else {
                UFitCatalogProductFormContent(draft: $store.draft, isNew: store.isNew, changesPublishedProduct: store.original?.product.status == .active,
                    currencies: store.currencies, errors: store.errors, hasChanges: store.hasChanges, isBusy: store.isBusy, message: store.message,
                    onBack: onBack, onSave: { Task { if let product = await store.save() { onSaved(product) } } },
                    onReloadCurrencies: { Task { await store.prepare(reloadMetadata: true) } }, onAddPhotos: { selectedPhotos = []; showingPhotos = true },
                    onRetryPhoto: store.retryPhoto, onRemovePhoto: store.removePhoto, renewPhotoSource: store.renewPhotoSource)
            }
        }
        .ufitPhotosPicker(isPresented: $showingPhotos, selection: $selectedPhotos,
            limit: max(Selection.minimumSlots, UFitCatalogInput.photosMax - store.draft.photos.count))
        .onChange(of: selectedPhotos) { _, _ in importSelection() }
        .onChange(of: showingPhotos) { _, _ in importSelection() }
        .task { if store.pendingCreation == nil { await store.prepare() } }
    }
    private func importSelection() {
        guard !showingPhotos, !selectedPhotos.isEmpty else { return }
        let selection = selectedPhotos; selectedPhotos = []
        for item in selection {
            store.addPhoto {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw UFitPhotoError.invalidImage }
                return data
            }
        }
    }
}
struct UFitCatalogStockHost: View {
    @Bindable var store: UFitCatalogStockStore
    let onBack: () -> Void
    var body: some View {
        UFitCatalogStockContent(variant: store.product.document.variantPresentation(store.variant), quantity: $store.quantity,
            error: store.error, message: store.message, isBusy: store.isBusy, hasChanges: store.hasChanges,
            onBack: onBack, onSave: { Task { if await store.save() { onBack() } } })
    }
}
