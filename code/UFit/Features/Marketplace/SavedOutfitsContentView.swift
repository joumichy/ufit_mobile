import SwiftUI

struct SavedOutfitsContentView: View {
    let outfits: [Outfit]
    @Binding var visibleOutfitID: String?
    let isAuthenticated: Bool
    let isLoading: Bool
    let hasLoaded: Bool
    let message: String?
    let isLoadingMore: Bool
    let hasMore: Bool
    let moreError: String?
    let onOutfitTap: (Outfit) -> Void
    let onBrowse: () -> Void
    let onRefresh: () async -> Void
    let onMore: () -> Void
    let onSignIn: () -> Void
    private enum Copy {
        static let title = String(localized: "Favoris")
        static let loading = String(localized: "Chargement de vos favoris")
        static let failed = String(localized: "Favoris indisponibles")
        static let retry = String(localized: "Réessayer")
        static let unavailableIcon = "wifi.exclamationmark"
        static let refresh = String(localized: "Actualiser les favoris")
        static let refreshIcon = "arrow.clockwise"
        static let more = String(localized: "Voir la suite")
        static let retryMore = String(localized: "Réessayer la suite")
        static let loadingMore = String(localized: "Chargement de la suite")
        static let pageChanged = String(localized: "Aucune tenue à afficher sur cette page.")
        static let signInTitle = String(localized: "Retrouvez vos favoris")
        static let signInMessage = String(localized: "Connectez-vous pour conserver les tenues qui vous inspirent.")
        static let signIn = String(localized: "Se connecter")
        static let bookmark = "bookmark"
    }
    private enum Anchor { static let more = "saved-outfits-more" }
    var body: some View {
        VStack(spacing: .zero) {
            HStack(spacing: .zero) {
                RootScreenHeader(title: Copy.title)
                if isAuthenticated, !outfits.isEmpty || (hasLoaded && !isLoading && message == nil) {
                    UFitButton(action: refresh) {
                        if isLoading { UFitLoading() }
                        else { UFitIcon(systemName: Copy.refreshIcon) }
                    }.ufitButtonStyle(.text).frame(minWidth: UFitControlSize.touch, minHeight: UFitControlSize.touch)
                        .padding(.trailing, UFitSpace.page).disabled(isLoading).accessibilityLabel(Copy.refresh)
                }
            }
            GeometryReader { viewport in
                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(alignment: .leading, spacing: UFitSpace.md) {
                            if !isAuthenticated {
                                UFitEmptyState(title: Copy.signInTitle, message: Copy.signInMessage, symbol: Copy.bookmark,
                                    actionTitle: Copy.signIn, actionKind: .primary, action: onSignIn)
                            } else if outfits.isEmpty {
                                if isLoading || (!hasLoaded && message == nil) { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                                else if let message {
                                    UFitEmptyState(title: Copy.failed, message: message, symbol: Copy.unavailableIcon,
                                        actionTitle: Copy.retry, action: refresh)
                                } else if hasMore { UFitNotice(message: Copy.pageChanged) }
                                else { EmptySavedState(onBrowse: onBrowse) }
                            } else {
                                if let message {
                                    UFitNotice(message: message, kind: .error)
                                    UFitActionButton(title: Copy.retry, kind: .secondary, action: refresh)
                                }
                                LazyVStack(spacing: UFitSpace.md) {
                                    ForEach(outfits) { outfit in
                                        UFitButton { onOutfitTap(outfit) } label: { SavedOutfitRow(outfit: outfit) }.ufitButtonStyle(.text)
                                    }
                                }.scrollTargetLayout()
                            }
                            if isAuthenticated, !isLoading, message == nil, isLoadingMore || moreError != nil || hasMore {
                                VStack(spacing: UFitSpace.md) {
                                    if isLoadingMore { UFitLoading(Copy.loadingMore).frame(maxWidth: .infinity) }
                                    else if let moreError {
                                        UFitNotice(message: moreError, kind: .error)
                                        UFitActionButton(title: Copy.retryMore, kind: .secondary, action: onMore)
                                    } else if hasMore { UFitActionButton(title: Copy.more, kind: .secondary, action: onMore) }
                                }.id(Anchor.more)
                            }
                        }.padding(UFitSpace.page).frame(minHeight: viewport.size.height, alignment: outfits.isEmpty ? .center : .topLeading)
                    }.scrollPosition(id: $visibleOutfitID).scrollIndicators(.hidden).ufitRefreshable { if isAuthenticated { await onRefresh() } }
                        .onChange(of: moreError) { _, failure in
                            // The error adds height below the pressed button; keep its retry in view.
                            if failure != nil { scroll.scrollTo(Anchor.more, anchor: .bottom) }
                        }
                }
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func refresh() { Task { await onRefresh() } }
}
