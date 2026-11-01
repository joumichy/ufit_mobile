import SwiftUI

struct SavedOutfitsContentView: View {
    let outfits: [Outfit]
    let isLoading: Bool
    let hasLoaded: Bool
    let message: String?
    let onOutfitTap: (Outfit) -> Void
    let onBrowse: () -> Void
    let onRefresh: () async -> Void
    private enum Copy {
        static let title = String(localized: "Favoris")
        static let loading = String(localized: "Chargement de vos favoris")
        static let failed = String(localized: "Favoris indisponibles")
        static let retry = String(localized: "Réessayer")
        static let unavailableIcon = "wifi.exclamationmark"
    }
    var body: some View {
        VStack(spacing: .zero) {
            RootScreenHeader(title: Copy.title)
            GeometryReader { viewport in
                ScrollView {
                    VStack(alignment: .leading, spacing: UFitSpace.md) {
                        if outfits.isEmpty {
                            if isLoading || (!hasLoaded && message == nil) { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                            else if let message {
                                UFitEmptyState(title: Copy.failed, message: message, symbol: Copy.unavailableIcon,
                                    actionTitle: Copy.retry, action: refresh)
                            } else { EmptySavedState(onBrowse: onBrowse) }
                        } else {
                            if let message {
                                UFitNotice(message: message, kind: .error)
                                UFitActionButton(title: Copy.retry, kind: .secondary, action: refresh)
                            }
                            LazyVStack(spacing: UFitSpace.md) {
                                ForEach(outfits) { outfit in
                                    UFitButton { onOutfitTap(outfit) } label: { SavedOutfitRow(outfit: outfit) }.ufitButtonStyle(.text)
                                }
                            }
                        }
                    }.padding(UFitSpace.page).frame(minHeight: viewport.size.height, alignment: outfits.isEmpty ? .center : .topLeading)
                }.scrollIndicators(.hidden).ufitRefreshable { await onRefresh() }
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func refresh() { Task { await onRefresh() } }
}
