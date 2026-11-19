import SwiftUI

struct UFitWorkspaceTransfersHost: View {
    let store: UFitWorkspaceTransfersStore
    let onBack: () -> Void; let onAccount: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        UFitWorkspaceTransfersContent(store: store, onBack: onBack, onAccount: onAccount)
            .task { await store.load() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } }
            .onDisappear { store.cancelLoading() }
    }
}
struct UFitWorkspaceTransfersContent: View {
    let store: UFitWorkspaceTransfersStore
    let onBack: () -> Void; let onAccount: () -> Void
    private typealias Copy = UFitWorkspaceTransfersCopy
    private enum Anchor { case top }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if store.canRead && store.isLoading { UFitLoading() }
            }
            if !store.canRead {
                UFitEmptyState(title: Copy.unavailable, message: Copy.unavailableScope, symbol: Copy.historyIcon,
                    actionTitle: Copy.back, action: onBack).frame(maxHeight: .infinity)
            } else {
                if store.message != nil && !store.failureAtEnd {
                    failure.padding(.horizontal, UFitSpace.page).padding(.vertical, UFitSpace.md)
                }
                ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: UFitSpace.xxl) {
                        Text(store.workspace.name).font(UFitTypography.title2).accessibilityAddTraits(.isHeader).id(Anchor.top)
                        if let document = store.document {
                            if document.totalCount == .zero {
                                UFitEmptyState(title: Copy.empty, message: Copy.emptyScope, symbol: Copy.historyIcon)
                            } else {
                                Text(Copy.scope).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                ForEach(document.currencies) { balance($0) }
                                UFitEditorialHeading(title: Copy.history, editorial: false)
                                ForEach(store.entries) { entry($0) }
                            }
                            if store.failureAtEnd { failure }
                            if store.message == nil && store.hasMore {
                                UFitActionButton(title: Copy.more, kind: .secondary, isBusy: store.operation == .more,
                                    disabled: store.isLoading) { Task { await store.load(refresh: false) } }
                            }
                            Text(Copy.consulted(document.asOf)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        } else if store.message == nil { UFitLoading(Copy.loading).frame(maxWidth: .infinity).padding(.vertical, UFitSpace.editorial) }
                        if store.workspace.status == .active {
                            UFitExperienceActionRow(title: Copy.account, systemImage: Copy.accountIcon, action: onAccount)
                        }
                    }.padding(.vertical, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.horizontal, UFitSpace.page)
                    .ufitRefreshable(isEnabled: store.canRead && !store.isLoading, title: Copy.refresh) { await store.refresh() }
                    .onChange(of: store.document?.revision) { previous, current in
                        if previous != nil && current != nil && previous != current { proxy.scrollTo(Anchor.top, anchor: .top) }
                    }
                }
            }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    @ViewBuilder private var failure: some View {
        if let message = store.message {
            VStack(alignment: .leading, spacing: UFitSpace.md) {
                UFitNotice(message: message, kind: .error)
                if store.readFailed && store.document != nil { Text(Copy.previous).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                UFitActionButton(title: store.retryRefresh && store.document != nil ? Copy.refreshHistory : Copy.retry,
                    kind: .secondary, isBusy: store.isLoading) { Task { await store.retry() } }
            }
        }
    }
    private func balance(_ value: UFitWorkspaceTransferCurrency) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
            HStack { Text(value.currency); Spacer(); Text(value.liveMode ? Copy.live : Copy.test) }.font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                Text(Copy.net).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                Text(UFitMoney.format(value.netTransferred, currency: value.currency)).font(UFitTypography.largeTitle.weight(.medium)).monospacedDigit()
            }.accessibilityElement(children: .combine)
            Grid(alignment: .leading, horizontalSpacing: UFitSpace.xl, verticalSpacing: UFitSpace.xs) {
                GridRow { Text(Copy.transferred); Text(Copy.recovered) }.font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                GridRow { amount(value.transferred, currency: value.currency); amount(value.recovered, currency: value.currency) }
            }
        }.padding(UFitSpace.lg).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card))
    }
    private func amount(_ value: Int, currency: String) -> some View { Text(UFitMoney.format(value, currency: currency)).font(UFitTypography.headline).monospacedDigit() }
    private func entry(_ row: UFitWorkspaceTransferEntry) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            HStack(alignment: .firstTextBaseline, spacing: UFitSpace.md) {
                Text(row.kind == .transfer ? Copy.transfer : Copy.reversal).font(UFitTypography.headline)
                Spacer(minLength: UFitSpace.sm); amount(row.signedAmount, currency: row.currency)
            }
            if let item = row.itemName { Text(item).font(UFitTypography.callout) }
            Text(row.brandName).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            HStack(alignment: .firstTextBaseline) {
                Text(row.orderNumber); Spacer(minLength: UFitSpace.sm)
                if !row.liveMode { Text(Copy.test) }
            }.font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            UFitLabeledValue(Copy.recorded, value: Copy.date(row.recordedAt)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            UFitDisclosure(Copy.details) {
                VStack(alignment: .leading, spacing: UFitSpace.md) {
                    reference(Copy.receipt, value: row.receiptId)
                    if let original = row.originalTransferId { reference(Copy.original, value: original) }
                    UFitLabeledValue(Copy.created, value: Copy.date(row.createdAt)).font(UFitTypography.caption)
                }
            }.font(UFitTypography.callout)
            Divider()
        }
    }
    private func reference(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xxs) {
            Text(title).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            Text(value).font(UFitTypography.caption.monospaced()).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }
}
