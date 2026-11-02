import SwiftUI

struct SavedOutfitsView: View {
    @Bindable var store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void
    let onBrowse: () -> Void
    let onSignIn: () -> Void
    var body: some View {
        SavedOutfitsContentView(outfits: store.savedOutfits, visibleOutfitID: $store.visibleSavedOutfitID, isAuthenticated: store.isAuthenticated,
            isLoading: store.isLoadingSavedOutfits, hasLoaded: store.hasLoadedSavedOutfits, message: store.savedErrorMessage,
            isLoadingMore: store.isLoadingMoreSavedOutfits, hasMore: store.hasMoreSavedOutfits, moreError: store.savedMoreError,
            onOutfitTap: { outfit in store.visibleSavedOutfitID = outfit.id; onOutfitTap(outfit) }, onBrowse: onBrowse, onRefresh: {
                await store.loadSavedOutfits()
                await store.loadSavedStates(ids: store.outfits.map(\.id), force: true)
            }, onMore: { Task { await store.loadMoreSavedOutfits() } }, onSignIn: onSignIn)
            .task(id: store.accountID) {
                if !store.hasLoadedSavedOutfits { await store.loadSavedOutfits() }
                await store.loadSavedStates(ids: store.outfits.map(\.id))
            }
    }
}
