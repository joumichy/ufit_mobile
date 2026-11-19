import SwiftUI

struct UFitAdminOrdersContent: View {
    @Bindable var store: UFitAdminOrdersStore
    let onBack: () -> Void; let onOpen: (String) -> Void
    private var rows: [UFitAdminOrderSummary] { store.canRead ? store.rows : [] }
    private let shipmentOptions: [UFitShipmentLifecycle] = [.pending, .preparing, .shipped, .delivered, .failed, .cancelled]
    private enum Copy {
        static let filters = String(localized: "Affiner les commandes")
        static let separator = " · "
    }
    private var activeFilters: String {
        [store.status?.label, store.currency, store.shipmentStatus?.label].compactMap { $0 }.joined(separator: Copy.separator)
    }
    var body: some View {
        VStack(spacing: .zero) {
            header
            ScrollView(.vertical, showsIndicators: true) {
                collection
                    .padding(.vertical, UFitSpace.lg)
            }.padding(.horizontal, UFitSpace.page)
                .scrollPosition(id: $store.visibleRowID, anchor: .top).scrollDismissesKeyboard(.interactively)
                .ufitRefreshable(isEnabled: !store.isLoading, title: UFitAdminOrdersCopy.refresh) { await store.refresh() }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .task { if !store.hasLoaded { await store.load() } }
            .onChange(of: store.selection) { _, _ in Task<Void, Never> { await store.selectionChanged() } }
            .onDisappear { store.cancelLoading() }
    }
    private var header: some View {
        DetailHeader(title: UFitAdminOrdersCopy.title, onBack: onBack)
    }
    private var collection: some View {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
            filters
            metadata
            if !store.messageAtEnd { failure }
            if rows.isEmpty { emptyState } else { orders }
        }
    }
    private var filters: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            UFitSearchField(query: $store.search, prompt: UFitAdminOrdersCopy.search)
            UFitDisclosure(Copy.filters) {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    filterGroup(UFitAdminOrdersCopy.status) { statusFilter }
                    filterGroup(UFitAdminOrdersCopy.currency) { currencyFilter }
                    filterGroup(UFitAdminOrdersCopy.shipping) {
                        UFitFilterChoices(title: UFitAdminOrdersCopy.shipping, selection: $store.shipmentStatus,
                            options: [.init(value: nil, title: UFitAdminOrdersCopy.allShipments)] + shipmentOptions.map { .init(value: Optional($0), title: $0.label) })
                    }
                }.padding(.top, UFitSpace.sm)
            }
            if !activeFilters.isEmpty { Text(activeFilters).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
        }
    }
    private func filterGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            Text(title).font(UFitTypography.subheadline.weight(.medium))
            content()
        }
    }
    @ViewBuilder private var metadata: some View {
        if let metadata = store.page, store.canRead {
            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                Text(UFitAdminOrdersCopy.count(metadata.totalCount)).font(UFitTypography.headline)
                Text(UFitAdminOrdersCopy.observed(metadata.asOf)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            }
        }
    }
    @ViewBuilder private var emptyState: some View {
        if store.isLoading || (!store.hasLoaded && store.message == nil) {
            UFitLoading(UFitAdminOrdersCopy.loading).frame(maxWidth: .infinity).padding(.vertical, UFitSpace.xl)
        } else if store.hasLoaded && store.message == nil {
            UFitEmptyState(title: store.selection.isFiltered ? UFitAdminOrdersCopy.noMatches : UFitAdminOrdersCopy.empty,
                symbol: UFitAdminOrdersCopy.icon, actionTitle: store.selection.isFiltered ? UFitAdminOrdersCopy.reset : nil,
                action: store.selection.isFiltered ? { store.reset() } : nil)
        }
    }
    private var orders: some View {
        VStack(spacing: UFitSpace.lg) {
            LazyVStack(spacing: .zero) {
                ForEach(rows) { row in
                    VStack(spacing: .zero) {
                        UFitButton { onOpen(row.id) } label: { UFitAdminOrderRowContent(order: row) }.ufitButtonStyle(.text)
                        Divider()
                    }.id(row.id)
                }
            }.scrollTargetLayout()
            if store.messageAtEnd { failure }
            if store.isLoading { UFitLoading().frame(maxWidth: .infinity) }
            if store.hasMore && store.message == nil {
                UFitActionButton(title: UFitAdminOrdersCopy.more, kind: .secondary, disabled: store.isLoading) { Task<Void, Never> { await store.load(reset: false) } }
            }
        }
    }
    private var statusFilter: some View {
        UFitFilterChoices(title: UFitAdminOrdersCopy.status, selection: $store.status,
            options: [.init(value: nil, title: UFitAdminOrdersCopy.allStatuses)] + UFitOrderLifecycle.allCases.map { .init(value: Optional($0), title: $0.label) })
    }
    private var currencyFilter: some View {
        UFitFilterChoices(title: UFitAdminOrdersCopy.currency, selection: $store.currency,
            options: [.init(value: nil, title: UFitAdminOrdersCopy.allCurrencies)] + store.currencies.map { .init(value: Optional($0), title: $0) })
    }
    @ViewBuilder private var failure: some View {
        if let message = store.message {
            UFitNotice(message: message, kind: .error)
            UFitActionButton(title: store.needsRefresh ? UFitAdminOrdersCopy.refresh : UFitAdminOrdersCopy.retry, kind: .secondary,
                disabled: store.isLoading) { Task { await store.retry() } }
        }
    }
}

private struct UFitAdminOrderRowContent: View {
    let order: UFitAdminOrderSummary
    var body: some View {
        HStack(alignment: .top, spacing: UFitSpace.md) {
            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                Text(order.orderNumber).font(UFitTypography.headline)
                Text(order.brand.name).font(UFitTypography.subheadline)
                Text(order.createdAt.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                Text(order.status.label).font(UFitTypography.subheadline.weight(.medium))
                if order.shipmentStatus == .failed { Text(UFitShipmentLifecycle.failed.label).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                HStack(alignment: .firstTextBaseline) {
                    Text(UFitOrderFormatting.pieceCount(order.itemCount)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    Spacer(minLength: UFitSpace.xs)
                    Text(UFitMoney.format(order.totalAmount, currency: order.currency)).font(UFitTypography.headline)
                }
                if order.returnCount > .zero { Text(UFitAdminOrdersCopy.returnsCount(order.returnCount)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
            }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            UFitIcon(systemName: UFitAdminOrdersCopy.nextIcon).font(UFitTypography.caption).accessibilityHidden(true)
        }.padding(.vertical, UFitSpace.md).frame(maxWidth: .infinity, minHeight: UFitControlSize.touch, alignment: .leading)
    }
}
