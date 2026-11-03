import SwiftUI
import Observation

@MainActor @Observable
final class UFitAdminOrdersFlowStore {
    enum Route { case list, detail(UFitAdminOrderDetailStore), returns(UFitAdminOrderReturnsStore), returnDetail(UFitReturnDetailStore), settlement(UFitPaymentSettlementStore), allocation(UFitPaymentAllocationStore) }
    let list: UFitAdminOrdersStore
    private(set) var route = Route.list
    @ObservationIgnored private var history = [Route]()
    init(session: UFitSessionStore) { list = .init(session: session) }
    var canGoBack: Bool { !history.isEmpty }
    func back() {
        guard let previous = history.popLast() else { return }
        switch route {
        case .list: list.cancelLoading()
        case .detail(let store): store.cancelLoading()
        case .returns(let store): store.cancelLoading()
        case .settlement(let store): store.cancelLoading()
        case .allocation(let store): store.cancelLoading()
        case .returnDetail: break
        }
        route = previous
    }
    func open(_ id: String) {
        guard case .list = route, list.canRead, list.rows.contains(where: { $0.id == id }) else { return }
        history.append(route); route = .detail(.init(id: id, collection: list))
    }
    func showReturns() {
        guard case .detail(let store) = route, list.canRead, let document = store.document else { return }
        history.append(route)
        route = .returns(.init(orderID: document.order.id, reference: document.order.orderNumber, collection: list))
    }
    func showSettlement(_ paymentID: String) {
        guard case .detail(let store) = route, list.canRead, let document = store.document,
              document.payments.contains(where: { $0.id == paymentID }) else { return }
        history.append(route)
        route = .settlement(.init(paymentID: paymentID, orderID: document.order.id, brandID: document.brand.id, collection: list))
    }
    func showAllocation() {
        guard case .settlement(let store) = route, list.canRead, !store.isLoading, !store.isSending,
              !store.needsStatusRefresh, let document = store.document else { return }
        history.append(route)
        route = .allocation(.init(reference: document, brandID: store.brandID, collection: list))
    }
    func openReturn(_ id: String) {
        guard case .returns(let store) = route, list.canRead, store.rows.contains(where: { $0.id == id }) else { return }
        do {
            let collection = try UFitReturnsStore(scope: .administrator, context: store.reference, session: list.session)
            let detail = try UFitReturnDetailStore(id: id, list: collection)
            history.append(route); route = .returnDetail(detail)
        } catch { list.revoke() }
    }
}

struct UFitAdminOrdersFlowHost: View {
    let store: UFitAdminOrdersFlowStore
    let onClose: () -> Void
    private var back: () -> Void { { if store.canGoBack { store.back() } else { onClose() } } }
    var body: some View {
        Group {
            if !store.list.isOwner || (!store.list.canRead && store.canGoBack) {
                UFitEmptyState(title: UFitUserAdministrationCopy.unavailable, message: UFitAdminOrdersCopy.access,
                    actionTitle: UFitAdminOrdersCopy.returnHome, action: onClose)
            } else {
                switch store.route {
                case .list: UFitAdminOrdersContent(store: store.list, onBack: back, onOpen: store.open)
                case .detail(let detail): UFitAdminOrderDetailContent(store: detail, onBack: back, onReturns: store.showReturns, onSettlement: store.showSettlement).id(detail.id)
                case .settlement(let settlement): UFitPaymentSettlementHost(store: settlement, onBack: back, onAllocation: store.showAllocation).id(settlement.paymentID)
                case .allocation(let allocation): UFitPaymentAllocationHost(store: allocation, onBack: back).id(allocation.reference.payment.id)
                case .returns(let returns): UFitAdminOrderReturnsContent(store: returns, onBack: back, onOpen: store.openReturn)
                case .returnDetail(let detail):
                    UFitReturnDetailHost(store: detail, onBack: back)
                        .onChange(of: detail.list.accessRevoked) { _, revoked in if revoked { store.list.revoke() } }
                }
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}

private struct UFitAdminOrderReturnsContent: View {
    let store: UFitAdminOrderReturnsStore
    let onBack: () -> Void; let onOpen: (String) -> Void
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitAdminOrdersCopy.returns, onBack: onBack) {
                UFitButton { Task { await store.refresh() } } label: { UFitIcon(systemName: UFitAdminOrdersCopy.refreshIcon) }
                    .accessibilityLabel(UFitAdminOrdersCopy.refresh).disabled(store.isLoading)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    Text(store.reference).font(UFitTypography.headline)
                    if !store.messageAtEnd { failure }
                    if store.rows.isEmpty {
                        if store.isLoading || (!store.hasLoaded && store.message == nil) { UFitLoading(UFitAdminOrdersCopy.loadingReturns).frame(maxWidth: .infinity) }
                        else if store.message == nil { UFitEmptyState(title: UFitAdminOrdersCopy.noReturns, symbol: UFitAdminOrdersCopy.icon) }
                    }
                    LazyVStack(spacing: .zero) {
                        ForEach(store.rows) { row in
                            VStack(spacing: .zero) {
                                UFitButton { onOpen(row.id) } label: {
                                    HStack(alignment: .top, spacing: UFitSpace.md) {
                                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                            Text(row.status.label).font(UFitTypography.headline)
                                            Text(row.requestedAt.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                            Text(UFitOrderFormatting.pieceCount(row.itemCount)).font(UFitTypography.callout)
                                            Text(UFitMoney.format(row.totalAmount, currency: row.currency)).font(UFitTypography.headline)
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        UFitIcon(systemName: UFitAdminOrdersCopy.nextIcon).accessibilityHidden(true)
                                    }.padding(.vertical, UFitSpace.md).frame(maxWidth: .infinity, minHeight: UFitControlSize.touch)
                                }.ufitButtonStyle(.text)
                                Divider()
                            }
                        }
                    }
                    if store.messageAtEnd { failure }
                    if !store.rows.isEmpty && store.isLoading { UFitLoading().frame(maxWidth: .infinity) }
                    if store.nextCursor != nil && store.message == nil {
                        UFitActionButton(title: UFitAdminOrdersCopy.more, kind: .secondary, disabled: store.isLoading) { Task { await store.load(reset: false) } }
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .task { if !store.hasLoaded { await store.load() } }.onDisappear { store.cancelLoading() }
    }
    @ViewBuilder private var failure: some View {
        if let message = store.message {
            UFitNotice(message: message, kind: .error)
            UFitActionButton(title: UFitAdminOrdersCopy.retry, kind: .secondary, disabled: store.isLoading) { Task { await store.retry() } }
        }
    }
}
