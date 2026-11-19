import SwiftUI

struct SearchOutfitsContentView: View {
    @Bindable var store: UFitOutfitSearchStore
    let onOutfitTap: (Outfit) -> Void
    var preferences: UFitStylePreferencesStore? = nil
    var onCollections: (() -> Void)? = nil
    @State private var showingFilters = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private typealias Copy = UFitOutfitSearchCopy
    var body: some View {
        VStack(spacing: .zero) {
            header
            VStack(alignment: .leading, spacing: UFitSpace.md) {
                UFitSearchField(query: $store.criteria.query, prompt: Copy.prompt)
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: UFitSpace.xs) { scopes; filters }
                } else {
                    HStack(spacing: UFitSpace.sm) { scopes; filters.fixedSize(horizontal: true, vertical: false) }
                }
                if store.isLoadingOptions { UFitLoading(Copy.loadingOptions) }
                else if !store.filterSummary.isEmpty {
                    Text(store.filterSummary).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let error = store.optionsError {
                    UFitNotice(message: error, kind: .error)
                    UFitButton(Copy.retryOptions) { Task { await store.loadOptions() } }.ufitButtonStyle(.secondary, compact: true)
                }
                if let preferences, !preferences.shortcuts.isEmpty {
                    UFitChoiceBar(title: UFitStylePreferencesCopy.shortcutTitle, selection: $store.criteria.styleID,
                        options: [.init(value: nil, title: UFitStylePreferencesCopy.all)] + preferences.shortcuts.map {
                            .init(value: Optional($0.id), title: $0.label)
                        })
                }
                if let message = store.message, !store.outfits.isEmpty {
                    UFitNotice(message: message, kind: .error)
                    UFitActionButton(title: Copy.retry, kind: .secondary, action: refresh)
                }
            }.padding(.horizontal, UFitSpace.page).padding(.bottom, UFitSpace.md)
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: UFitSpace.md) {
                        if store.outfits.isEmpty {
                            if store.isLoading || (!store.hasLoaded && store.message == nil) {
                                UFitLoading(Copy.loading).frame(maxWidth: .infinity)
                            } else if store.isQueryTooLong {
                                UFitEmptyState(title: Copy.queryTooLongTitle, message: Copy.queryTooLong, symbol: Copy.searchIcon)
                            } else if let message = store.message {
                                UFitEmptyState(title: Copy.failed, message: message, symbol: Copy.errorIcon,
                                    actionTitle: Copy.retry, action: refresh)
                            } else {
                                UFitEmptyState(title: store.criteria.isRefined ? Copy.empty : Copy.noOutfits,
                                    message: store.criteria.isRefined ? Copy.emptyMessage : nil, symbol: Copy.searchIcon,
                                    actionTitle: store.criteria.isRefined ? Copy.clear : Copy.refresh,
                                    action: { if store.criteria.isRefined { store.criteria = .init() } else { refresh() } })
                            }
                        } else {
                            LazyVStack(spacing: UFitSpace.md) {
                                ForEach(store.outfits) { outfit in
                                    UFitButton { onOutfitTap(outfit) } label: { SavedOutfitRow(outfit: outfit) }.ufitButtonStyle(.text)
                                }
                            }.scrollTargetLayout()
                        }
                        if !store.isLoading, store.message == nil, store.hasMore || store.moreError != nil || store.isLoadingMore {
                            VStack(spacing: UFitSpace.md) {
                                if store.isLoadingMore { UFitLoading(Copy.loadingMore).frame(maxWidth: .infinity) }
                                else {
                                    if let message = store.moreError { UFitNotice(message: message, kind: .error) }
                                    UFitActionButton(title: store.moreError == nil ? Copy.more : Copy.retryMore, kind: .secondary,
                                        action: { Task { await store.more() } })
                                }
                            }.id(Copy.moreAnchor)
                        }
                    }.padding(.horizontal, UFitSpace.page).padding(.bottom, UFitSpace.page).padding(.top, UFitSpace.xs)
                }.scrollPosition(id: $store.visibleOutfitID).scrollDismissesKeyboard(.interactively).scrollIndicators(.hidden)
                    .ufitRefreshable(isEnabled: !store.isLoading, title: Copy.refresh) { await store.search() }
                    .onChange(of: store.moreError) { _, error in if error != nil { scroll.scrollTo(Copy.moreAnchor, anchor: .bottom) } }
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .ufitSheet(isPresented: $showingFilters) {
                if let options = store.options {
                    UFitOutfitFiltersContent(initial: store.criteria, options: options,
                        onApply: { store.criteria = $0; showingFilters = false }, onClose: { showingFilters = false })
                }
            }
            .task(id: store.criteria) { await store.loadIfNeeded() }
            .task { if store.options == nil { await store.loadOptions() } }
    }
    private var heading: some View {
        Text(Copy.title).ufitFont(size: UFitTypography.Size.title, design: .serif)
            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }
    @ViewBuilder private var collections: some View {
        if let onCollections {
            UFitButton(action: onCollections) {
                Text(UFitEditorialCopy.title).font(UFitTypography.subheadline.weight(.medium))
            }.ufitButtonStyle(.secondary, compact: true).accessibilityLabel(UFitEditorialCopy.open)
        }
    }
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: UFitSpace.sm) {
                heading.fixedSize(); Spacer(minLength: .zero); collections.fixedSize(); loadingIndicator
            }
            VStack(alignment: .leading, spacing: UFitSpace.sm) {
                heading
                HStack { collections; Spacer(minLength: .zero); loadingIndicator }
            }
        }.padding(.horizontal, UFitSpace.page).padding(.top, UFitSpace.lg).padding(.bottom, UFitSpace.lg)
    }
    @ViewBuilder private var loadingIndicator: some View {
        if store.isLoading { UFitLoading().frame(width: UFitControlSize.touch, height: UFitControlSize.touch) }
    }
    private var scopes: some View {
        UFitChoiceBar(title: Copy.scope, selection: $store.criteria.scope,
            options: UFitOutfitSearchScope.allCases.map { .init(value: $0, title: $0.title) }, appearance: .underline)
    }
    private var filters: some View {
        UFitButton { showingFilters = true } label: {
            HStack(spacing: UFitSpace.xs) { UFitIcon(systemName: Copy.filterIcon); Text(Copy.filters) }
                .font(UFitTypography.subheadline.weight(.medium))
        }.ufitButtonStyle(.secondary, compact: true).disabled(store.options == nil)
    }
    private func refresh() { Task { await store.search() } }
}
