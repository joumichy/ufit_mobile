import SwiftUI

struct UFitCommissionRulesContent: View {
    let rows: [UFitCommissionRuleRow]
    let brand: UFitCommissionReference?
    let isLoading: Bool
    let hasLoaded: Bool
    let hasMore: Bool
    let openingIDs: Set<String>
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onFilter: () -> Void
    let onCreate: () -> Void
    let onOpen: (String) -> Void
    let onMore: () -> Void
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch }
    private enum Icon { static let add = "plus"; static let filter = "line.3.horizontal.decrease"; static let next = "chevron.right"; static let refresh = "arrow.clockwise" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitCommissionAdminCopy.title, onBack: onBack) {
                UFitButton(action: onRefresh) { UFitIcon(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }
                    .disabled(isLoading).accessibilityLabel(UFitCommissionAdminCopy.refresh)
                if !rows.isEmpty || !hasLoaded || isLoading || message != nil {
                    UFitButton(action: onCreate) { UFitIcon(systemName: Icon.add).frame(width: Layout.touch, height: Layout.touch) }
                        .accessibilityLabel(UFitCommissionAdminCopy.create)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    UFitButton(action: onFilter) {
                        HStack { Text(brand?.title ?? UFitCommissionAdminCopy.allBrands); Spacer(); UFitIcon(systemName: Icon.filter) }
                    }.frame(minHeight: Layout.touch).accessibilityLabel(UFitCommissionAdminCopy.brand)
                        .accessibilityValue(brand?.title ?? UFitCommissionAdminCopy.allBrands)
                    if let message {
                        Text(message).font(UFitTypography.callout)
                        UFitActionButton(title: UFitCommissionAdminCopy.retry, kind: .secondary, action: onRefresh).disabled(isLoading)
                    }
                    if rows.isEmpty {
                        if isLoading || (!hasLoaded && message == nil) { UFitLoading(UFitCommissionAdminCopy.loading).frame(maxWidth: .infinity) }
                        else if hasLoaded && message == nil {
                            Text(UFitCommissionAdminCopy.empty).font(UFitTypography.title3)
                            Text(UFitCommissionAdminCopy.missingRule).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                            UFitButton(action: onCreate) { Text(UFitCommissionAdminCopy.create).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary)
                        }
                    } else {
                        VStack(spacing: .zero) {
                            ForEach(rows) { row in
                                UFitButton { onOpen(row.id) } label: {
                                    HStack(alignment: .top, spacing: Layout.gap) {
                                        VStack(alignment: .leading, spacing: Layout.small) {
                                            Text(row.brand).font(UFitTypography.headline)
                                            Text(row.product ?? UFitCommissionAdminCopy.allProducts).font(UFitTypography.subheadline)
                                            Text(row.grade ?? UFitCommissionAdminCopy.allGrades).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                            Text(row.active ? UFitCommissionAdminCopy.active : UFitCommissionAdminCopy.inactive).font(UFitTypography.caption)
                                        }
                                        Spacer(minLength: Layout.gap)
                                        if openingIDs.contains(row.id) { UFitLoading() }
                                        else { Text(row.rate).font(UFitTypography.headline); UFitIcon(systemName: Icon.next).font(UFitTypography.caption) }
                                    }.frame(maxWidth: .infinity, minHeight: Layout.touch, alignment: .leading).padding(.vertical, Layout.gap)
                                }.disabled(openingIDs.contains(row.id))
                                Divider()
                            }
                        }
                        if isLoading { UFitLoading().frame(maxWidth: .infinity) }
                        if hasMore { UFitActionButton(title: UFitCommissionAdminCopy.more, kind: .secondary, action: onMore).disabled(isLoading) }
                    }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
