import SwiftUI

struct UFitCatalogListContent: View {
    let title: String
    let subtitle: String?
    let access: UFitCatalogAccess
    let rows: [UFitCatalogRow]
    let selectedStatus: UFitCatalogStatus?
    let hasLoaded: Bool
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let busyIDs: Set<String>
    let message: String?
    let onBack: () -> Void
    let onSelectStatus: (UFitCatalogStatus?) -> Void
    let onRefresh: () async -> Void
    let onMore: () async -> Void
    let onOpen: (String) -> Void
    let onCreate: () -> Void
    private enum Copy {
        static let refresh = String(localized: "Actualiser"); static let create = String(localized: "Nouveau produit")
        static let clearFilter = String(localized: "Voir tous les produits")
        static let filter = String(localized: "Statut"); static let all = String(localized: "Tous")
        static let loading = String(localized: "Chargement du catalogue")
        static let empty = String(localized: "Aucun produit pour ce filtre.")
        static let emptyBrand = String(localized: "Votre catalogue est vide")
        static let more = String(localized: "Voir plus de produits"); static let retry = String(localized: "Réessayer")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let title: CGFloat = UFitTypography.Size.editorial
        static let touch: CGFloat = UFitControlSize.touch; static let bottom: CGFloat = 110; static let imageWidth: CGFloat = 88; static let imageHeight: CGFloat = 112; static let radius: CGFloat = UFitRadius.field
    }
    private enum Icon { static let create = "plus"; static let photo = "photo"; static let chevron = "chevron.right" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                HStack {
                    if isLoading && hasLoaded { UFitLoading().frame(width: Layout.touch, height: Layout.touch) }
                    if access == .member && (!rows.isEmpty || selectedStatus != nil) { UFitButton(action: onCreate) { UFitIcon(systemName: Icon.create).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.create) }
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(title).ufitFont(size: Layout.title, design: .serif).accessibilityAddTraits(.isHeader)
                        if let subtitle { Text(subtitle).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                    }
                    UFitChoiceBar(title: Copy.filter, selection: Binding(get: { selectedStatus }, set: onSelectStatus), options: [.init(value: nil, title: Copy.all)] + UFitCatalogStatus.allCases.map { .init(value: Optional($0), title: $0.label) }).frame(minHeight: Layout.touch)
                    if let message {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(message).font(UFitTypography.callout)
                            UFitActionButton(title: Copy.retry, kind: .secondary) { Task { await onRefresh() } }
                        }
                    }
                    if !hasLoaded && message == nil { UFitLoading(Copy.loading).frame(maxWidth: .infinity).padding(.vertical, Layout.page) }
                    if hasLoaded && rows.isEmpty && message == nil && !isLoading {
                        Text(access == .member && selectedStatus == nil ? Copy.emptyBrand : Copy.empty).font(UFitTypography.title2)
                        if selectedStatus != nil { UFitActionButton(title: Copy.clearFilter, kind: .secondary) { onSelectStatus(nil) } }
                        else if access == .member { UFitButton(action: onCreate) { Text(Copy.create).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary) }
                    }
                    LazyVStack(spacing: Layout.page) {
                        ForEach(rows) { row in
                            UFitButton(action: { onOpen(row.id) }) {
                                HStack(alignment: .center, spacing: Layout.gap) {
                                    Group { if let image = row.image { FashionImage(source: image) } else { Rectangle().fill(Color.ufitCanvas).overlay { UFitIcon(systemName: Icon.photo).foregroundStyle(Color.ufitSecondaryText) } } }
                                        .frame(width: Layout.imageWidth, height: Layout.imageHeight).clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                                    VStack(alignment: .leading, spacing: Layout.small) {
                                        Text(row.status.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                        Text(row.name).font(UFitTypography.headline).multilineTextAlignment(.leading)
                                        Text(row.price).font(UFitTypography.subheadline)
                                    }
                                    Spacer()
                                    if busyIDs.contains(row.id) { UFitLoading() } else { UFitIcon(systemName: Icon.chevron).font(UFitTypography.caption) }
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.ufitButtonStyle(.text).disabled(busyIDs.contains(row.id))
                        }
                    }
                    if hasMore {
                        if isLoadingMore { UFitLoading().frame(maxWidth: .infinity, minHeight: Layout.touch) }
                        else { UFitActionButton(title: Copy.more, kind: .secondary) { Task { await onMore() } } }
                    }
                }.padding(Layout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable(isEnabled: !isLoading, title: Copy.refresh) { await onRefresh() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
