import SwiftUI

struct UFitRefundRecoveryContent: View {
    let rows: [UFitRefundRecoveryRow]
    @Binding var search: String
    @Binding var kind: UFitRefundRecoveryKind?
    let totalCount: Int?
    let isLoading: Bool
    let hasLoaded: Bool
    let hasMore: Bool
    let isFiltered: Bool
    let openingIDs: Set<UFitRefundRecoveryReference>
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onSearch: () -> Void
    let onReset: () -> Void
    let onMore: () -> Void
    let onOpen: (UFitRefundRecoveryReference) -> Void
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitRefundRecoveryCopy.title, onBack: onBack) {
                UFitButton(action: onRefresh) {UFitIcon(systemName: UFitRefundRecoveryCopy.refreshIcon)}
                    .accessibilityLabel(UFitRefundRecoveryCopy.refresh).disabled(isLoading)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    UFitSearchField(query: $search, prompt: UFitRefundRecoveryCopy.search).onSubmit(onSearch)
                    UFitSelection(UFitRefundRecoveryCopy.kind, selection: $kind, options:
                        [.init(value: Optional<UFitRefundRecoveryKind>.none, title: UFitRefundRecoveryCopy.allKinds)] +
                        UFitRefundRecoveryKind.allCases.map {.init(value: Optional($0), title: $0.label)})
                    if let message {
                        UFitNotice(message: message, kind: .error)
                        UFitButton(UFitRefundRecoveryCopy.retry, action: onRefresh).ufitButtonStyle(.secondary).disabled(isLoading)
                    }
                    if let totalCount, totalCount > .zero {Text(UFitRefundRecoveryCopy.count(totalCount)).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)}
                    if rows.isEmpty {
                        if isLoading || (!hasLoaded && message == nil) {UFitLoading(UFitRefundRecoveryCopy.loading).frame(maxWidth: .infinity).padding(.vertical, UFitSpace.xl)}
                        else if hasLoaded && message == nil {
                            UFitEmptyState(title: isFiltered ? UFitRefundRecoveryCopy.noMatches : UFitRefundRecoveryCopy.empty, symbol: UFitRefundRecoveryCopy.icon,
                                actionTitle: isFiltered ? UFitRefundRecoveryCopy.reset : nil, action: isFiltered ? onReset : nil)
                        }
                    } else {
                        LazyVStack(spacing: .zero) {
                            ForEach(rows, id: \.reference) {row in
                                UFitButton {onOpen(row.reference)} label: {
                                    HStack(alignment: .top, spacing: UFitSpace.md) {
                                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                            Text(row.orderNumber).font(UFitTypography.headline)
                                            Text(row.context).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                                            Text(row.amount).font(UFitTypography.headline)
                                            Text(row.failedAt).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                        }.fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: UFitSpace.sm)
                                        if openingIDs.contains(row.reference) {UFitLoading()}
                                        else {UFitIcon(systemName: UFitRefundRecoveryCopy.next).font(UFitTypography.caption).accessibilityHidden(true)}
                                    }.padding(.vertical, UFitSpace.md).frame(maxWidth: .infinity, minHeight: UFitControlSize.touch, alignment: .leading)
                                }.disabled(openingIDs.contains(row.reference))
                                Divider()
                            }
                        }
                        if isLoading {UFitLoading().frame(maxWidth: .infinity)}
                        if hasMore {UFitButton(UFitRefundRecoveryCopy.more, action: onMore).ufitButtonStyle(.secondary).disabled(isLoading)}
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}
struct UFitRefundRecoveryDetailContent: View {
    let document: UFitRefundRecoveryDocument?
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onSource: () -> Void
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitRefundRecoveryCopy.title, onBack: onBack) {
                UFitButton(action: onRefresh) {UFitIcon(systemName: UFitRefundRecoveryCopy.refreshIcon)}
                    .accessibilityLabel(UFitRefundRecoveryCopy.refresh).disabled(isLoading)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    if let message {
                        UFitNotice(message: message, kind: .error)
                        UFitButton(UFitRefundRecoveryCopy.retry, action: onRefresh).ufitButtonStyle(.secondary).disabled(isLoading)
                    }
                    if let document {
                        let row = document.row
                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                            Text(row.orderNumber).font(UFitTypography.title2.weight(.semibold))
                            Text(row.context).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                        }
                        Text(row.amount).font(UFitTypography.editorialTitle)
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            Text(UFitRefundRecoveryCopy.pending).font(UFitTypography.headline)
                            Text(document.explanation).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        }
                        UFitLabeledValue( UFitRefundRecoveryCopy.failedAt, value: row.failedAt).font(UFitTypography.callout)
                        if let reference = document.providerReference {UFitLabeledValue( UFitRefundRecoveryCopy.paymentReference, value: reference).font(UFitTypography.callout)}
                        UFitButton(document.sourceTitle, action: onSource).ufitButtonStyle(.secondary).disabled(isLoading)
                    } else if isLoading {UFitLoading(UFitRefundRecoveryCopy.loading).frame(maxWidth: .infinity)}
                    else {UFitEmptyState(title: UFitRefundRecoveryCopy.unavailable, symbol: UFitRefundRecoveryCopy.icon, actionTitle: UFitRefundRecoveryCopy.backToQueue, action: onBack)}
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}
