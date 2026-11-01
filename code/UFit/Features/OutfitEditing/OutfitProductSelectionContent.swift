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
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch; static let imageWidth: CGFloat = 88; static let imageHeight: CGFloat = 112; static let radius: CGFloat = UFitRadius.field }
    private enum Icon { static let photo = "tshirt"; static let selected = "checkmark"; static let add = "plus" }
    var body: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: Copy.title, onClose: { onClose() })
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    UFitTextField(label: Copy.search, text: $search)
                        .submitLabel(.search).onSubmit { Task { await onSearch() } }
                    UFitButton(Copy.searchAction) { Task { await onSearch() } }.frame(minHeight: Layout.touch).disabled(isLoading)
                    if let message {
                        Text(message).font(UFitTypography.callout)
                        UFitButton(Copy.retry) { Task { await onSearch() } }.frame(minHeight: Layout.touch)
                    }
                    if isLoading { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    if hasLoaded && products.isEmpty && !isLoading { Text(Copy.empty).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                    LazyVStack(spacing: Layout.page) {
                        ForEach(products) { product in
                            UFitButton { onSelect(product) } label: {
                                HStack(spacing: Layout.gap) {
                                    Group {
                                        if let source = product.image { FashionImage(source: source) }
                                        else { Rectangle().fill(Color.ufitCanvas).overlay { UFitIcon(systemName: Icon.photo) } }
                                    }.frame(width: Layout.imageWidth, height: Layout.imageHeight).clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                                    VStack(alignment: .leading, spacing: Layout.small) {
                                        Text(product.name).font(UFitTypography.headline).multilineTextAlignment(.leading)
                                        if let brand = product.brandName { Text(brand).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                                        if let price = product.price { Text(price).font(UFitTypography.subheadline) }
                                        if selectedIDs.contains(product.id) { Text(Copy.added).font(UFitTypography.caption) }
                                    }
                                    Spacer()
                                    UFitIcon(systemName: selectedIDs.contains(product.id) ? Icon.selected : Icon.add).frame(minWidth: Layout.touch, minHeight: Layout.touch)
                                }.contentShape(Rectangle())
                            }.ufitButtonStyle(.text).disabled(selectedIDs.contains(product.id))
                        }
                    }
                    if hasMore {
                        if isLoadingMore { UFitLoading().frame(maxWidth: .infinity, minHeight: Layout.touch) }
                        else { UFitButton(Copy.more) { Task { await onMore() } }.frame(maxWidth: .infinity, minHeight: Layout.touch) }
                    }
                }.padding(Layout.page)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk)
    }
}
