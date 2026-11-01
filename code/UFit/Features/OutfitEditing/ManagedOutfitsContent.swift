import SwiftUI

struct UFitManagedOutfitsContent: View {
    let title: String
    let subtitle: String?
    let access: UFitOutfitAccess
    let rows: [UFitManagedOutfitRow]
    let selectedStatus: UFitOutfitStatus?
    let hasLoaded: Bool
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let busyIDs: Set<String>
    let message: String?
    let onBack: () -> Void
    let onSelectStatus: (UFitOutfitStatus?) -> Void
    let onRefresh: () async -> Void
    let onMore: () async -> Void
    let onOpen: (String) -> Void
    let onCreate: () -> Void
    private enum Copy {
        static let refresh = String(localized: "Actualiser"); static let create = String(localized: "Nouvelle tenue")
        static let clearFilter = String(localized: "Voir toutes les tenues")
        static let filter = String(localized: "Statut"); static let all = String(localized: "Toutes les tenues")
        static let loading = String(localized: "Chargement des tenues")
        static let empty = String(localized: "Aucune tenue pour ce filtre.")
        static let emptyBrand = String(localized: "Votre première tenue.")
        static let more = String(localized: "Voir plus de tenues"); static let retry = String(localized: "Réessayer")
    }
    private enum Layout {
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let title: CGFloat = 32
        static let touch: CGFloat = 44; static let bottom: CGFloat = 110; static let imageWidth: CGFloat = 88; static let imageHeight: CGFloat = 112; static let radius: CGFloat = 12
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let create = "plus"; static let photo = "photo"; static let chevron = "chevron.right" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                HStack {
                    if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                    else { Button { Task { await onRefresh() } } label: { Image(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
                    if access == .author && (!rows.isEmpty || selectedStatus != nil) { Button(action: onCreate) { Image(systemName: Icon.create).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.create) }
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(title).font(.system(size: Layout.title, design: .serif))
                        if let subtitle { Text(subtitle).font(.callout).foregroundStyle(Color.ufitMuted) }
                    }
                    Picker(Copy.filter, selection: Binding(get: { selectedStatus }, set: onSelectStatus)) {
                        Text(Copy.all).tag(UFitOutfitStatus?.none)
                        ForEach(UFitOutfitStatus.allCases) { status in Text(status.label).tag(Optional(status)) }
                    }.pickerStyle(.menu).frame(minHeight: Layout.touch)
                    if let message {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(message).font(.callout)
                            Button(Copy.retry) { Task { await onRefresh() } }.frame(minHeight: Layout.touch)
                        }
                    }
                    if !hasLoaded && isLoading { ProgressView(Copy.loading).frame(maxWidth: .infinity).padding(.vertical, Layout.page) }
                    if hasLoaded && rows.isEmpty {
                        Text(access == .author && selectedStatus == nil ? Copy.emptyBrand : Copy.empty).font(.title2)
                        if selectedStatus != nil { Button(Copy.clearFilter) { onSelectStatus(nil) }.frame(minHeight: Layout.touch) }
                        else if access == .author { Button(action: onCreate) { Text(Copy.create).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()) }
                    }
                    LazyVStack(spacing: Layout.page) {
                        ForEach(rows) { row in
                            Button(action: { onOpen(row.id) }) {
                                HStack(alignment: .center, spacing: Layout.gap) {
                                    Group { if let image = row.image { FashionImage(source: image) } else { Rectangle().fill(Color.ufitBackground).overlay { Image(systemName: Icon.photo).foregroundStyle(Color.ufitMuted) } } }
                                        .frame(width: Layout.imageWidth, height: Layout.imageHeight).clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                                    VStack(alignment: .leading, spacing: Layout.small) {
                                        Text(row.status.label).font(.caption).foregroundStyle(Color.ufitMuted)
                                        Text(row.title).font(.headline).multilineTextAlignment(.leading)
                                        if access == .moderator, let author = row.author { Text(author).font(.caption).foregroundStyle(Color.ufitMuted) }
                                        Text(row.price).font(.subheadline)
                                    }
                                    Spacer()
                                    if busyIDs.contains(row.id) { ProgressView() } else { Image(systemName: Icon.chevron).font(.caption) }
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(busyIDs.contains(row.id))
                        }
                    }
                    if hasMore {
                        if isLoadingMore { ProgressView().frame(maxWidth: .infinity, minHeight: Layout.touch) }
                        else { Button(Copy.more) { Task { await onMore() } }.frame(maxWidth: .infinity, minHeight: Layout.touch) }
                    }
                }.padding(Layout.page).padding(.bottom, Layout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }.refreshable { await onRefresh() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
}
