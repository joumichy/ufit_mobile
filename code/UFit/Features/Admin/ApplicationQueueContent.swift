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
        static let all = String(localized: "Tous")
        static let status = String(localized: "Statut de candidature")
        static let kind = String(localized: "Profil candidat")
        static let empty = String(localized: "Aucune candidature dans cette sélection.")
        static let separator = " · "
        static let chevron = "chevron.right"
    }
    private enum Layout { static let spacing: CGFloat = UFitSpace.xl; static let inline: CGFloat = 10; static let title: CGFloat = UFitTypography.Size.editorial; static let touch: CGFloat = UFitControlSize.touch; static let bottom: CGFloat = 110 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) { if isLoading { UFitLoading() } }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    Text(Copy.title).ufitFont(size: Layout.title, design: .serif).accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: Layout.inline) {
                        UFitChoiceBar(title: Copy.kind, selection: Binding(get: { kind }, set: onKind),
                            options: [.init(value: nil, title: Copy.all)] + UFitApplicationKind.allCases.map { .init(value: Optional($0), title: $0.label) },
                            appearance: .underline)
                        UFitChoiceBar(title: Copy.status, selection: Binding(get: { filter }, set: onFilter),
                            options: UFitApplicationQueueFilter.allCases.map { .init(value: $0, title: $0.label) }, appearance: .chips)
                    }
                    if let message {
                        Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        UFitActionButton(title: Copy.refresh, kind: .secondary, disabled: isLoading, action: onRefresh)
                    }
                    if hasLoaded && items.isEmpty && message == nil && !isLoading { Text(Copy.empty).foregroundStyle(Color.ufitSecondaryText) }
                    LazyVStack(spacing: .zero) {
                        ForEach(items, id: \.identity) { item in
                            UFitButton { onOpen(item) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: Layout.inline) {
                                        Text(item.name).font(UFitTypography.headline)
                                        Text(item.type.label + Copy.separator + item.status.label).font(UFitTypography.subheadline)
                                        Text(item.submittedAt.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    UFitIcon(systemName: Copy.chevron).accessibilityHidden(true)
                                }.frame(minHeight: Layout.touch).padding(.vertical, Layout.inline)
                            }.ufitButtonStyle(.text)
                            Divider()
                        }
                    }
                    if hasMore { UFitActionButton(title: Copy.more, kind: .secondary, action: onMore).disabled(isLoading) }
                }.padding(Layout.spacing).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable(isEnabled: !isLoading, title: Copy.refresh) { onRefresh() }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}
