import SwiftUI

struct SearchOutfitsContentView: View {
    @Bindable var store: UFitOutfitSearchStore
    let onOutfitTap: (Outfit) -> Void
    @State private var showingFilters = false
    private typealias Copy = UFitOutfitSearchCopy
    var body: some View {
        VStack(spacing: .zero) {
            HStack(spacing: .zero) {
                RootScreenHeader(title: Copy.title)
                UFitButton { Task { await store.search() } } label: {
                    if store.isLoading { UFitLoading() } else { UFitIcon(systemName: Copy.refreshIcon) }
                }.ufitButtonStyle(.text).frame(minWidth: UFitControlSize.touch, minHeight: UFitControlSize.touch)
                    .disabled(store.isLoading).accessibilityLabel(Copy.refresh).padding(.trailing, UFitSpace.page)
            }
            VStack(alignment: .leading, spacing: UFitSpace.md) {
                UFitSearchField(query: $store.criteria.query, prompt: Copy.prompt)
                UFitChoiceBar(title: Copy.scope, selection: $store.criteria.scope,
                    options: UFitOutfitSearchScope.allCases.map { .init(value: $0, title: $0.title) })
                HStack(spacing: UFitSpace.md) {
                    UFitButton { showingFilters = true } label: {
                        HStack(spacing: UFitSpace.xs) { UFitIcon(systemName: Copy.filterIcon); Text(Copy.filters) }
                    }.ufitButtonStyle(.secondary, compact: true).disabled(store.options == nil)
                    if store.isLoadingOptions { UFitLoading(Copy.loadingOptions) }
                    else if !store.filterSummary.isEmpty {
                        Text(store.filterSummary).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: .zero)
                }
                if let error = store.optionsError {
                    UFitNotice(message: error, kind: .error)
                    UFitButton(Copy.retryOptions) { Task { await store.loadOptions() } }.ufitButtonStyle(.text)
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
                    }.padding(UFitSpace.page)
                }.scrollPosition(id: $store.visibleOutfitID).scrollDismissesKeyboard(.interactively).scrollIndicators(.hidden)
                    .ufitRefreshable { await store.search() }
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
    private func refresh() { Task { await store.search() } }
}
