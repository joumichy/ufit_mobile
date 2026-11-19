import SwiftUI

struct UFitEditorialHost: View {
    let store: UFitEditorialStore
    let session: UFitSessionStore
    let cart: UFitCartStore
    let onBack: () -> Void
    let onOutfit: (Outfit) -> Void
    let onBrand: (String) -> Void
    let onCart: () -> Void
    let onSignIn: () -> Void
    var body: some View {
        Group {
            if let product = store.product {
                UFitPublicProductContent(store: product, session: session, cart: cart, onBack: back, onBrand: onBrand, onCart: onCart, onSignIn: onSignIn)
            } else if let collection = store.collection {
                UFitEditorialCollectionContent(store: collection, onBack: back, onOpen: { entry in
                    if entry.itemType == .product { store.openProduct(entry, session: session) }
                    else { Task { if let outfit = await collection.openOutfit(entry), store.collection === collection { onOutfit(outfit) } } }
                })
            } else { UFitEditorialListContent(store: store, onBack: back) }
        }.environment(\.ufitPrimarySection, false).onDisappear { store.collection?.cancelOpening() }
    }
    private func back() { if !store.back() { onBack() } }
}

private struct UFitEditorialListContent: View {
    @Bindable var store: UFitEditorialStore
    let onBack: () -> Void
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack)
            if !store.collections.isEmpty, let message = store.message {
                EditorialRefreshFailure(message: message, actionTitle: UFitEditorialCopy.retry, action: refresh)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    UFitEditorialHeading(title: UFitEditorialCopy.title, eyebrow: UFitEditorialCopy.eyebrow)
                    if store.collections.isEmpty {
                        if store.isLoading || (!store.hasLoaded && store.message == nil) { UFitLoading(UFitEditorialCopy.loading) }
                        else if let message = store.message {
                            UFitEmptyState(title: UFitEditorialCopy.failed, message: message, symbol: UFitEditorialCopy.errorIcon,
                                actionTitle: UFitEditorialCopy.retry, action: refresh)
                        } else {
                            UFitEmptyState(title: UFitEditorialCopy.empty, symbol: UFitEditorialCopy.icon,
                                actionTitle: UFitEditorialCopy.backToSearch, action: onBack)
                        }
                    } else {
                        if store.isLoading { UFitLoading(UFitEditorialCopy.loading) }
                        LazyVStack(alignment: .leading, spacing: UFitSpace.xl) {
                            ForEach(store.collections) { collection in
                                UFitButton { store.open(collection) } label: {
                                    VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                        EditorialCover(url: collection.coverImageUrl).aspectRatio(EditorialLayout.coverRatio, contentMode: .fit)
                                        HStack(alignment: .firstTextBaseline, spacing: UFitSpace.md) {
                                            Text(collection.title).font(UFitTypography.title2).fixedSize(horizontal: false, vertical: true)
                                            Spacer(minLength: UFitSpace.xs)
                                            UFitIcon(systemName: UFitEditorialCopy.chevron).font(UFitTypography.caption)
                                        }
                                        if let subtitle = collection.subtitle { Text(subtitle).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                                        Text(UFitEditorialCopy.count(collection.itemCount)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.ufitButtonStyle(.text).id(collection.id)
                            }
                        }.scrollTargetLayout()
                    }
                    if store.message == nil && !store.isLoading {
                        EditorialMore(hasMore: store.hasMore, isLoading: store.isLoadingMore, error: store.moreError) { Task { await store.more() } }
                    }
                }.padding(.vertical, UFitSpace.page)
            }.padding(.horizontal, UFitSpace.page).scrollPosition(id: $store.visibleCollectionID, anchor: .top)
                .ufitRefreshable(isEnabled: !store.isLoading, title: UFitEditorialCopy.refresh) { await store.load() }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas).task { if !store.hasLoaded { await store.load() } }
    }
    private func refresh() { Task { await store.load() } }
}

private struct UFitEditorialCollectionContent: View {
    @Bindable var store: UFitEditorialCollectionStore
    let onBack: () -> Void
    let onOpen: (UFitEditorialEntry) -> Void
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitEditorialCopy.title, onBack: onBack)
            if store.collection != nil, let message = store.message {
                EditorialRefreshFailure(message: message, actionTitle: UFitEditorialCopy.refresh, action: refresh)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    if store.isUnavailable && !store.isLoading {
                        UFitEmptyState(title: UFitEditorialCopy.unavailable, message: UFitEditorialCopy.missing, symbol: UFitEditorialCopy.icon,
                            actionTitle: UFitEditorialCopy.refresh, action: refresh)
                    } else if let collection = store.collection {
                        UFitEditorialHeading(title: collection.title, eyebrow: UFitEditorialCopy.eyebrow)
                        if let subtitle = collection.subtitle { Text(subtitle).font(UFitTypography.title3).foregroundStyle(Color.ufitSecondaryText) }
                        Text(collection.description).font(UFitTypography.body).fixedSize(horizontal: false, vertical: true)
                        if store.isLoading { UFitLoading(UFitEditorialCopy.loadingCollection) }
                        LazyVStack(alignment: .leading, spacing: UFitSpace.xl) {
                            ForEach(store.entries) { entry in
                                VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                    UFitButton { onOpen(entry) } label: {
                                        HStack(alignment: .center, spacing: UFitSpace.md) {
                                            EditorialCover(url: entry.imageUrl).frame(width: EditorialLayout.referenceWidth, height: EditorialLayout.referenceHeight)
                                            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                                Text(entry.itemType == .outfit ? UFitEditorialCopy.outfit : UFitEditorialCopy.product)
                                                    .font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                                Text(entry.title).font(UFitTypography.headline).fixedSize(horizontal: false, vertical: true)
                                            }.frame(maxWidth: .infinity, alignment: .leading)
                                            if store.busyEntries.contains(entry.id) { UFitLoading() }
                                            else { UFitIcon(systemName: UFitEditorialCopy.chevron).font(UFitTypography.caption) }
                                        }
                                    }.ufitButtonStyle(.text).disabled(store.busyEntries.contains(entry.id))
                                    if let error = store.entryErrors[entry.id] { UFitNotice(message: error, kind: .error) }
                                }.id(entry.id)
                            }
                        }.scrollTargetLayout()
                        if store.entries.isEmpty { UFitEmptyState(title: UFitEditorialCopy.emptyItems, symbol: UFitEditorialCopy.icon, actionTitle: UFitEditorialCopy.refresh, action: refresh) }
                        if store.message == nil && !store.isLoading {
                            EditorialMore(hasMore: store.hasMore, isLoading: store.isLoadingMore, error: store.moreError) { Task { await store.more() } }
                        }
                    } else if store.isLoading || store.message == nil { UFitLoading(UFitEditorialCopy.loadingCollection).frame(maxWidth: .infinity) }
                    else {
                        UFitEmptyState(title: UFitEditorialCopy.collectionFailedTitle, message: store.message, symbol: UFitEditorialCopy.errorIcon,
                            actionTitle: UFitEditorialCopy.retry, action: refresh)
                    }
                }.padding(.vertical, UFitSpace.page)
            }.padding(.horizontal, UFitSpace.page).scrollPosition(id: $store.visibleEntryID, anchor: .top)
                .ufitRefreshable(isEnabled: !store.isLoading, title: UFitEditorialCopy.refresh) { await store.load() }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas).task { if !store.hasLoaded { await store.load() } }
            .onDisappear { store.cancelOpening() }
    }
    private func refresh() { Task { await store.load() } }
}

private struct EditorialRefreshFailure: View {
    let message: String
    let actionTitle: String
    let action: () -> Void
    var body: some View {
        VStack(spacing: UFitSpace.sm) {
            UFitNotice(message: message, kind: .error)
            UFitActionButton(title: actionTitle, kind: .secondary, action: action)
        }.padding(.horizontal, UFitSpace.page).padding(.bottom, UFitSpace.md)
    }
}
private struct EditorialCover: View {
    let url: String?
    var body: some View {
        Rectangle().fill(Color.ufitSecondary).overlay {
            if let url { FashionImage(source: url).clipped() }
            else { UFitIcon(systemName: UFitEditorialCopy.photo).foregroundStyle(Color.ufitSecondaryText).accessibilityHidden(true) }
        }.clipped().accessibilityHidden(true)
    }
}
private struct EditorialMore: View {
    let hasMore: Bool
    let isLoading: Bool
    let error: String?
    let action: () -> Void
    var body: some View {
        if hasMore || error != nil || isLoading {
            VStack(spacing: UFitSpace.md) {
                if isLoading { UFitLoading(UFitEditorialCopy.loadingMore) }
                else {
                    if let error { UFitNotice(message: error, kind: .error) }
                    UFitActionButton(title: error == nil ? UFitEditorialCopy.more : UFitEditorialCopy.retry, kind: .secondary, action: action)
                }
            }.frame(maxWidth: .infinity)
        }
    }
}
private enum EditorialLayout {
    static let coverRatio: CGFloat = 1
    static let referenceWidth: CGFloat = 92
    static let referenceHeight: CGFloat = 122
}
