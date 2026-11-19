import SwiftUI
import Observation

@MainActor @Observable
final class UFitRefundRecoveryFlowStore {
    enum Route {
        case list
        case detail(UFitRefundRecoveryDetailStore)
        case order(UFitBrandOrderStore)
        case orderReturn(UFitReturnDetailStore)
    }
    let list: UFitRefundRecoveryStore
    private(set) var route = Route.list
    @ObservationIgnored private var history = [Route]()
    init(session: UFitSessionStore) {list = UFitRefundRecoveryStore(session: session)}
    var canGoBack: Bool {!history.isEmpty}
    func back() {
        guard let previous = history.popLast() else {return}
        route = previous
        if case .detail(let detail) = previous {Task {await detail.load()}}
    }
    func open(_ reference: UFitRefundRecoveryReference) async {
        guard case .list = route, list.isCurrentAccount, let detail = await list.open(reference), case .list = route else {return}
        history.append(route); route = .detail(detail)
    }
    func showOrigin() {
        guard case .detail(let detail) = route, detail.isCurrentAccount, !detail.isLoading, let source = detail.document?.summary else {return}
        do {
            let destination: Route
            switch source.kind {
            case .orderReturn:
                let collection = try UFitReturnsStore(scope: .administrator, context: UFitRefundRecoveryCopy.title, session: list.session)
                destination = .orderReturn(try UFitReturnDetailStore(id: source.id, list: collection))
            case .cancellation:
                let collection = try UFitBrandOrdersStore(administrating: source.brandId, brandName: source.brandName, session: list.session)
                destination = .order(try UFitBrandOrderStore(id: source.orderId, list: collection))
            }
            history.append(route); route = destination
        } catch {detail.report(error)}
    }
}
struct UFitRefundRecoveryFlowHost: View {
    let store: UFitRefundRecoveryFlowStore
    let onClose: () -> Void
    private var onBack: () -> Void {{if store.canGoBack {store.back()} else {onClose()}}}
    var body: some View {
        switch store.route {
        case .list: UFitRefundRecoveryHost(store: store.list, onBack: onBack, onOpen: {reference in Task {await store.open(reference)}})
        case .detail(let detail): UFitRefundRecoveryDetailHost(store: detail, onBack: onBack, onSource: store.showOrigin)
        case .order(let order): UFitBrandOrderHost(store: order, onBack: onBack)
        case .orderReturn(let orderReturn): UFitReturnDetailHost(store: orderReturn, onBack: onBack)
        }
    }
}
