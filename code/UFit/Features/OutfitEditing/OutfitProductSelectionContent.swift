import SwiftUI

struct UFitOutfitProductSelectionContent: View {
    @Binding var search: String
    let products: [UFitOutfitProductChoice]
    let selectedIDs: Set<String>
    let isLoading: Bool
    let hasLoaded: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let message: String?
    let onClose: () -> Void
    let onSearch: () async -> Void
    let onMore: () async -> Void
    let onSelect: (UFitOutfitProductChoice) -> Void
    private enum Copy {
        static let title = String(localized: "Choisir un produit"); static let search = String(localized: "Rechercher un produit")
        static let searchAction = String(localized: "Rechercher"); static let close = String(localized: "Fermer")
        static let empty = String(localized: "Aucun produit disponible pour cette recherche."); static let loading = String(localized: "Chargement des produits")
        static let added = String(localized: "Déjà dans la tenue"); static let more = String(localized: "Voir plus de produits"); static let retry = String(localized: "Réessayer")
    }
    private enum Layout { static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44; static let imageWidth: CGFloat = 88; static let imageHeight: CGFloat = 112; static let radius: CGFloat = 12 }
    private enum Icon { static let photo = "tshirt"; static let selected = "checkmark"; static let add = "plus" }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    UFitTextField(label: Copy.search, text: $search)
                        .submitLabel(.search).onSubmit { Task { await onSearch() } }
                    Button(Copy.searchAction) { Task { await onSearch() } }.frame(minHeight: Layout.touch).disabled(isLoading)
                    if let message {
                        Text(message).font(.callout)
                        Button(Copy.retry) { Task { await onSearch() } }.frame(minHeight: Layout.touch)
                    }
                    if isLoading { ProgressView(Copy.loading).frame(maxWidth: .infinity) }
                    if hasLoaded && products.isEmpty && !isLoading { Text(Copy.empty).font(.callout).foregroundStyle(Color.ufitMuted) }
                    LazyVStack(spacing: Layout.page) {
                        ForEach(products) { product in
                            Button { onSelect(product) } label: {
                                HStack(spacing: Layout.gap) {
                                    Group {
                                        if let source = product.image { FashionImage(source: source) }
                                        else { Rectangle().fill(Color.ufitBackground).overlay { Image(systemName: Icon.photo) } }
                                    }.frame(width: Layout.imageWidth, height: Layout.imageHeight).clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                                    VStack(alignment: .leading, spacing: Layout.small) {
                                        Text(product.name).font(.headline).multilineTextAlignment(.leading)
                                        if let brand = product.brandName { Text(brand).font(.caption).foregroundStyle(Color.ufitMuted) }
                                        if let price = product.price { Text(price).font(.subheadline) }
                                        if selectedIDs.contains(product.id) { Text(Copy.added).font(.caption) }
                                    }
                                    Spacer()
                                    Image(systemName: selectedIDs.contains(product.id) ? Icon.selected : Icon.add).frame(minWidth: Layout.touch, minHeight: Layout.touch)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(selectedIDs.contains(product.id))
                        }
                    }
                    if hasMore {
                        if isLoadingMore { ProgressView().frame(maxWidth: .infinity, minHeight: Layout.touch) }
                        else { Button(Copy.more) { Task { await onMore() } }.frame(maxWidth: .infinity, minHeight: Layout.touch) }
                    }
                }.padding(Layout.page)
            }.scrollDismissesKeyboard(.interactively).navigationTitle(Copy.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(Copy.close, action: onClose) } }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk)
    }
}
