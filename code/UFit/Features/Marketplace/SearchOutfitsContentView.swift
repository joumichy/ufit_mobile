import SwiftUI

struct SearchOutfitsContentView: View {
    let outfits: [Outfit]
    let isLoading: Bool
    let hasLoaded: Bool
    let message: String?
    let onRefresh: () async -> Void
    let onOutfitTap: (Outfit) -> Void
    @State private var query = String()
    @State private var scope = SearchScope.all
    private enum Copy {
        static let title = String(localized: "Trouver une tenue")
        static let subtitle = String(localized: "Dans les tenues de votre sélection.")
        static let scope = String(localized: "Rechercher dans")
        static let loading = String(localized: "Chargement des tenues")
        static let failed = String(localized: "La sélection est indisponible")
        static let empty = String(localized: "Aucune tenue disponible")
        static let retry = String(localized: "Réessayer")
        static let refresh = String(localized: "Actualiser")
        static let unavailableIcon = "wifi.exclamationmark"
        static let emptyIcon = "rectangle.stack"
    }
    private enum SearchScope: String, CaseIterable {
        case all, creators, pieces
        var title: String {
            switch self { case .all: String(localized: "Tous les champs"); case .creators: String(localized: "Nom du créateur"); case .pieces: String(localized: "Nom des pièces") }
        }
        func values(_ outfit: Outfit) -> [String] {
            switch self {
            case .all: [outfit.title, outfit.creator, outfit.description] + outfit.products.map(\.name) + outfit.pieces.map(\.name)
            case .creators: [outfit.creator]
            case .pieces: outfit.products.map(\.name) + outfit.pieces.map(\.name)
            }
        }
    }
    private var filteredOutfits: [Outfit] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return outfits.filter { search.isEmpty || scope.values($0).contains { $0.localizedStandardContains(search) } }
    }
    var body: some View {
        VStack(spacing: .zero) {
            RootScreenHeader(title: Copy.title, subtitle: Copy.subtitle)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    SearchField(query: $query)
                    UFitChoiceBar(title: Copy.scope, selection: $scope, options: SearchScope.allCases.map { .init(value: $0, title: $0.title) }).padding(.horizontal, UFitSpace.page)
                    if let message, !outfits.isEmpty {
                        UFitNotice(message: message, kind: .error).padding(.horizontal, UFitSpace.page)
                        UFitActionButton(title: Copy.retry, kind: .secondary, action: refresh).padding(.horizontal, UFitSpace.page)
                    }
                    if outfits.isEmpty {
                        if isLoading || (!hasLoaded && message == nil) { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                        else if let message {
                            UFitEmptyState(title: Copy.failed, message: message, symbol: Copy.unavailableIcon,
                                actionTitle: Copy.retry, action: refresh)
                        } else {
                            UFitEmptyState(title: Copy.empty, symbol: Copy.emptyIcon, actionTitle: Copy.refresh, action: refresh)
                        }
                    }
                    else if filteredOutfits.isEmpty { EmptySearchState().padding(.horizontal, UFitSpace.page) }
                    else {
                        LazyVStack(spacing: UFitSpace.md) {
                            ForEach(filteredOutfits) { outfit in UFitButton { onOutfitTap(outfit) } label: { SavedOutfitRow(outfit: outfit) }.ufitButtonStyle(.text) }
                        }.padding(.horizontal, UFitSpace.page)
                    }
                }.padding(.bottom, UFitSpace.xl)
            }.scrollDismissesKeyboard(.interactively).scrollIndicators(.hidden).ufitRefreshable { await onRefresh() }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func refresh() { Task { await onRefresh() } }
}
