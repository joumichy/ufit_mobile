import SwiftUI

struct UFitCommissionRuleDetailContent: View {
    let document: UFitCommissionRuleDocument?
    let history: [UFitCommissionRevisionRow]
    let isLoading: Bool
    let hasMore: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let onMore: () -> Void
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch; static let rate: CGFloat = 40 }
    private enum Icon { static let refresh = "arrow.clockwise" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitCommissionAdminCopy.rules, onBack: onBack) {
                UFitButton(action: onRefresh) { UFitIcon(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }
                    .disabled(isLoading).accessibilityLabel(UFitCommissionAdminCopy.refresh)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let message { Text(message).font(UFitTypography.callout); UFitButton(UFitCommissionAdminCopy.retry, action: onRefresh).frame(minHeight: Layout.touch).disabled(isLoading) }
                    if let document {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(document.rule.brand).font(UFitTypography.title2)
                            Text(document.rule.product ?? UFitCommissionAdminCopy.allProducts)
                            Text(document.rule.grade ?? UFitCommissionAdminCopy.allGrades).foregroundStyle(Color.ufitSecondaryText)
                        }
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(UFitCommissionAdminCopy.finalRate).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                            Text(document.rule.rate).ufitFont(size: Layout.rate, design: .serif)
                            Text(document.rule.active ? UFitCommissionAdminCopy.active : UFitCommissionAdminCopy.inactive).font(UFitTypography.subheadline)
                            HStack { Text(UFitCommissionAdminCopy.version); Text(document.rule.revision, format: .number) }.font(UFitTypography.caption)
                        }
                        VStack(spacing: Layout.gap) {
                            UFitLabeledValue(UFitCommissionAdminCopy.baseRate, value: document.baseRate)
                            UFitLabeledValue(UFitCommissionAdminCopy.bonusRate, value: document.bonusRate)
                            UFitLabeledValue(UFitCommissionAdminCopy.maximumRate, value: document.maximumRate ?? UFitCommissionAdminCopy.noMaximum)
                        }.font(UFitTypography.subheadline)
                        UFitButton(action: onEdit) { Text(UFitCommissionAdminCopy.edit).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary)
                        Text(UFitCommissionAdminCopy.priority).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        Divider()
                        Text(UFitCommissionAdminCopy.history).font(UFitTypography.title2)
                        ForEach(history) { revision in
                            VStack(alignment: .leading, spacing: Layout.small) {
                                HStack { Text(UFitCommissionAdminCopy.version); Text(revision.revision, format: .number); Spacer(); Text(revision.rate) }.font(UFitTypography.headline)
                                if revision.isCurrent { Text(UFitCommissionAdminCopy.current).font(UFitTypography.caption) }
                                Text(revision.date).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                Text(revision.active ? UFitCommissionAdminCopy.active : UFitCommissionAdminCopy.inactive).font(UFitTypography.caption)
                                if let reason = revision.reason { Text(reason).font(UFitTypography.callout) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Divider()
                        }
                        if hasMore { UFitButton(UFitCommissionAdminCopy.more, action: onMore).frame(minHeight: Layout.touch).disabled(isLoading) }
                    }
                    if isLoading { UFitLoading(UFitCommissionAdminCopy.loading).frame(maxWidth: .infinity) }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
    }
}
