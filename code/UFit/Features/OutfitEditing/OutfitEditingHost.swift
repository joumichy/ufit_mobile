import SwiftUI
import PhotosUI

struct UFitManagedOutfitsHost: View {
    let store: UFitManagedOutfitsStore
    let onBack: () -> Void
    let onOpen: (UFitManagedOutfitStore) -> Void
    let onCreate: (UFitManagedOutfitsStore) -> Void
    var body: some View {
        UFitManagedOutfitsContent(title: store.title, subtitle: store.subtitle, access: store.access, rows: store.rows,
            selectedStatus: store.selectedStatus, hasLoaded: store.hasLoaded, isLoading: store.isLoading,
            isLoadingMore: store.isLoadingMore, hasMore: store.nextCursor != nil, busyIDs: store.busyIDs, message: store.message,
            onBack: onBack, onSelectStatus: { status in Task { await store.filter(status) } }, onRefresh: { await store.load() },
            onMore: { await store.more() }, onOpen: { id in Task { if let outfit = await store.open(id) { onOpen(outfit) } } }, onCreate: { onCreate(store) })
            .task { await store.load() }.onDisappear { store.cancelOpening() }
    }
}
struct UFitManagedOutfitHost: View {
    let store: UFitManagedOutfitStore
    let onBack: () -> Void
    let onEdit: (UFitManagedOutfitStore) -> Void
    var body: some View {
        UFitManagedOutfitContent(outfit: store.document.presentation(), access: store.collection.access, isLoading: store.isLoading,
            isMutating: store.isMutating, message: store.message, onBack: onBack, onRefresh: { Task { await store.load() } }, onEdit: { onEdit(store) },
            onSubmit: { revision in Task { await store.mutate(revision, action: .submit) } },
            onApprove: { revision in Task { await store.mutate(revision, action: .review, decision: .published) } },
            onReject: { revision, reason in Task { await store.mutate(revision, action: .review, decision: .rejected, reason: reason) } },
            onArchive: { revision in Task { await store.mutate(revision, action: .archive) } },
            onRestore: { revision in Task { await store.mutate(revision, action: .restore) } })
    }
}
struct UFitOutfitFormHost: View {
    @Bindable var store: UFitOutfitFormStore
    let onBack: () -> Void
    let onSaved: (UFitManagedOutfit) -> Void
    @State private var showingPhotos = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var productSelection: UFitOutfitProductSelectionStore?
    private enum Selection { static let minimumSlots = 1 }
    var body: some View {
        Group {
            if store.needsCreationRecovery, let pending = store.pendingCreation {
                UFitOutfitCreationRecoveryContent(title: pending.request.title, isBusy: store.isBusy, message: store.message,
                    onBack: onBack, onResume: { Task { if let outfit = await store.resumeCreation() { onSaved(outfit) } } })
            } else if let metadata = store.metadata, store.hasPrepared {
                UFitOutfitFormContent(draft: $store.draft, tags: metadata.tags, isNew: store.isNew, changesPublishedOutfit: store.original?.status == .published,
                    hasChanges: store.hasChanges, isBusy: store.isBusy, errors: store.errors, message: store.message, onBack: onBack,
                    onSave: { Task { if let outfit = await store.save() { onSaved(outfit) } } }, onReloadTags: { Task { await store.prepare() } },
                    onAddPhotos: { selectedPhotos = []; showingPhotos = true }, onRetryPhoto: store.retryPhoto, onRemovePhoto: store.removePhoto,
                    onSelectProduct: { productSelection = UFitOutfitProductSelectionStore(form: store) })
            } else {
                UFitOutfitPreparationContent(isLoading: store.isLoading, message: store.message, onBack: onBack, onRetry: { Task { await store.prepare() } })
            }
        }
        .photosPicker(isPresented: $showingPhotos, selection: $selectedPhotos,
            maxSelectionCount: max(Selection.minimumSlots, UFitOutfitInput.photosMax - store.draft.photos.count),
            selectionBehavior: .ordered, matching: .images, preferredItemEncoding: .current)
        .onChange(of: selectedPhotos) { _, _ in importSelection() }
        .onChange(of: showingPhotos) { _, _ in importSelection() }
        .sheet(item: $productSelection) { selection in
            UFitOutfitProductSelectionHost(store: selection, onClose: { productSelection = nil }, onSelect: { choice in
                if selection.select(choice) { productSelection = nil }
            })
        }
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
struct UFitOutfitProductSelectionHost: View {
    @Bindable var store: UFitOutfitProductSelectionStore
    let onClose: () -> Void
    let onSelect: (UFitOutfitProductChoice) -> Void
    var body: some View {
        UFitOutfitProductSelectionContent(search: $store.search, products: store.products, selectedIDs: store.selectedIDs,
            isLoading: store.isLoading, hasLoaded: store.hasLoaded, isLoadingMore: store.isLoadingMore,
            hasMore: store.nextCursor != nil, message: store.message, onClose: onClose, onSearch: { await store.load() },
            onMore: { await store.more() }, onSelect: onSelect)
            .task { await store.load() }.onDisappear { store.cancel() }
    }
}
