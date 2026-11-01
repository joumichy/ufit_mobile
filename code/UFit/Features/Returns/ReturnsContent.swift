import SwiftUI

struct UFitReturnsContent: View {
    let context: String
    let returns: [UFitReturnSummaryPresentation]
    let selectedStatus: UFitReturnStatus?
    let hasLoaded: Bool
    let isLoading: Bool
    let hasMore: Bool
    let message: String?
    let canCreate: Bool
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onMore: () -> Void
    let onSelect: (String) -> Void
    let onStatus: (UFitReturnStatus?) -> Void
    let onCreate: () -> Void
    private enum Copy {
        static let title = String(localized: "Retours"); static let refresh = String(localized: "Actualiser les retours")
        static let status = String(localized: "Statut du retour"); static let all = String(localized: "Tous les statuts")
        static let empty = String(localized: "Aucun retour pour le moment"); static let emptyStatus = String(localized: "Aucun retour à ce statut")
        static let loading = String(localized: "Chargement des retours"); static let retry = String(localized: "Réessayer")
        static let more = String(localized: "Voir les retours précédents"); static let create = String(localized: "Demander un retour")
    }
    private enum Layout {
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44
        static let title: CGFloat = 30; static let referenceScale = 0.85
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let chevron = "chevron.right" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                else { Button(action: onRefresh) { Image(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Layout.page) {
                    Text(context).font(.system(size: Layout.title, design: .serif))
                    Picker(Copy.status, selection: Binding(get: { selectedStatus }, set: onStatus)) {
                        Text(Copy.all).tag(Optional<UFitReturnStatus>.none)
                        ForEach(UFitReturnStatus.allCases) { Text($0.label).tag(Optional($0)) }
                    }.pickerStyle(.menu).frame(minHeight: Layout.touch).accessibilityValue(selectedStatus?.label ?? Copy.all)
                    if hasLoaded && returns.isEmpty && !isLoading && message == nil {
                        Text(selectedStatus == nil ? Copy.empty : Copy.emptyStatus).font(.title3).foregroundStyle(Color.ufitMuted)
                    }
                    ForEach(returns) { item in
                        Button { onSelect(item.id) } label: {
                            HStack(alignment: .top, spacing: Layout.gap) {
                                VStack(alignment: .leading, spacing: Layout.small) {
                                    Text(item.orderNumber).font(.headline).lineLimit(1).minimumScaleFactor(Layout.referenceScale)
                                    Text(item.date).font(.subheadline).foregroundStyle(Color.ufitMuted)
                                    Text(item.status.label).font(.subheadline.weight(.medium))
                                    HStack { Text(item.pieces); Spacer(); Text(item.amount).fontWeight(.medium) }.font(.subheadline)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: Icon.chevron).font(.caption)
                            }.frame(minHeight: Layout.touch).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                    if let message { Text(message).font(.callout); Button(Copy.retry, action: onRefresh).frame(minHeight: Layout.touch) }
                    if isLoading || (!hasLoaded && message == nil) { ProgressView(Copy.loading).frame(maxWidth: .infinity) }
                    else if hasMore { Button(Copy.more, action: onMore).frame(minHeight: Layout.touch) }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            }.refreshable { onRefresh() }
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if canCreate { Button(action: onCreate) { Text(Copy.create).padding(.horizontal, Layout.gap).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).padding(Layout.gap).background(Color.white).overlay(alignment: .top) { Divider() } }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
}
