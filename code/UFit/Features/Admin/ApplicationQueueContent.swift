import SwiftUI

struct UFitApplicationQueueContent: View {
    let items: [UFitApplicationQueueItem]
    let filter: UFitApplicationQueueFilter
    let kind: UFitApplicationKind?
    let isLoading: Bool
    let hasLoaded: Bool
    let hasMore: Bool
    let message: String?
    let onBack: () -> Void
    let onFilter: (UFitApplicationQueueFilter) -> Void
    let onKind: (UFitApplicationKind?) -> Void
    let onRefresh: () -> Void
    let onMore: () -> Void
    let onOpen: (UFitApplicationQueueItem) -> Void
    private enum Copy {
        static let title = String(localized: "Candidatures")
        static let refresh = String(localized: "Actualiser")
        static let more = String(localized: "Voir la suite")
        static let allKinds = String(localized: "Créateurs et marques")
        static let empty = String(localized: "Aucune candidature dans cette sélection.")
        static let separator = " · "
        static let chevron = "chevron.right"
    }
    private enum Layout { static let spacing: CGFloat = 24; static let inline: CGFloat = 10; static let title: CGFloat = 32; static let touch: CGFloat = 44; static let bottom: CGFloat = 110 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) { if isLoading { ProgressView() } else { Button(Copy.refresh, action: onRefresh).frame(minHeight: Layout.touch) } }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    Text(Copy.title).font(.system(size: Layout.title, design: .serif))
                    VStack(alignment: .leading, spacing: Layout.inline) {
                        Menu(filter.label) { ForEach(UFitApplicationQueueFilter.allCases) { item in Button(item.label) { onFilter(item) } } }.frame(minHeight: Layout.touch)
                        Menu(kind?.label ?? Copy.allKinds) {
                            Button(Copy.allKinds) { onKind(nil) }
                            ForEach(UFitApplicationKind.allCases) { item in Button(item.label) { onKind(item) } }
                        }.frame(minHeight: Layout.touch)
                    }.tint(Color.ufitInk)
                    if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted) }
                    if hasLoaded && items.isEmpty { Text(Copy.empty).foregroundStyle(Color.ufitMuted) }
                    LazyVStack(spacing: .zero) {
                        ForEach(items, id: \.identity) { item in
                            Button { onOpen(item) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: Layout.inline) {
                                        Text(item.name).font(.headline)
                                        Text(item.type.label + Copy.separator + item.status.label).font(.subheadline)
                                        Text(item.submittedAt.label).font(.caption).foregroundStyle(Color.ufitMuted)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: Copy.chevron).accessibilityHidden(true)
                                }.frame(minHeight: Layout.touch).padding(.vertical, Layout.inline)
                            }.buttonStyle(.plain)
                            Divider()
                        }
                    }
                    if hasMore { Button(Copy.more, action: onMore).frame(minHeight: Layout.touch).disabled(isLoading) }
                }.padding(Layout.spacing).padding(.bottom, Layout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).background(Color.white)
    }
}
