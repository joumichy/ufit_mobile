import SwiftUI

struct UFitCommissionReferenceContent: View {
    let title: String
    let noneTitle: String?
    let rows: [UFitCommissionReference]
    let selectedID: String?
    @Binding var search: String
    let isLoading: Bool
    let hasLoaded: Bool
    let hasMore: Bool
    let message: String?
    let onClose: () -> Void
    let onSearch: () -> Void
    let onChoose: (UFitCommissionReference?) -> Void
    let onMore: () -> Void
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let touch: CGFloat = UFitControlSize.touch }
    private enum Icon { static let close = "xmark"; static let selected = "checkmark" }
    var body: some View {
        VStack(spacing: .zero) {
            HStack {
                Text(title).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                Spacer()
                UFitButton(action: onClose) { UFitIcon(systemName: Icon.close).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(UFitCommissionAdminCopy.close)
            }.padding(.horizontal, Layout.page)
            HStack(spacing: Layout.gap) {
                UFitSearchField(query: $search, prompt: UFitCommissionAdminCopy.search)
                    .submitLabel(.search).onSubmit(onSearch).frame(minHeight: Layout.touch)
                UFitButton(UFitCommissionAdminCopy.search, action: onSearch).ufitButtonStyle(.secondary, compact: true).disabled(isLoading)
            }.padding(.horizontal, Layout.page)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.gap) {
                    if let noneTitle { option(nil, title: noneTitle, detail: nil) }
                    if let message { Text(message).font(UFitTypography.callout); UFitActionButton(title: UFitCommissionAdminCopy.retry, kind: .secondary, action: onSearch).disabled(isLoading) }
                    ForEach(rows) { row in option(row, title: row.title, detail: row.detail) }
                    if isLoading || (!hasLoaded && message == nil) { UFitLoading(UFitCommissionAdminCopy.searching).frame(maxWidth: .infinity) }
                    else if hasLoaded && rows.isEmpty && message == nil { Text(UFitCommissionAdminCopy.optionEmpty).foregroundStyle(Color.ufitSecondaryText) }
                    if hasMore { UFitActionButton(title: UFitCommissionAdminCopy.more, kind: .secondary, action: onMore).disabled(isLoading) }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.padding(.top, Layout.gap).ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func option(_ row: UFitCommissionReference?, title: String, detail: String?) -> some View {
        VStack(spacing: .zero) {
            UFitButton { onChoose(row) } label: {
                HStack {
                    VStack(alignment: .leading) { Text(title); if let detail { Text(detail).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) } }
                    Spacer()
                    if selectedID == row?.id { UFitIcon(systemName: Icon.selected).accessibilityHidden(true) }
                }.frame(maxWidth: .infinity, minHeight: Layout.touch, alignment: .leading)
            }.accessibilityAddTraits(selectedID == row?.id ? .isSelected : [])
                .accessibilityRemoveTraits(selectedID == row?.id ? [] : .isSelected)
            Divider()
        }
    }
}
