import SwiftUI
import Observation

@MainActor @Observable
final class UFitDistributionFlowStore {
    enum Route { case brands, detail(UFitDistributionDetailStore), form(UFitDistributionFormStore), history(UFitDistributionHistoryStore) }
    let brands: UFitDistributionBrandsStore
    private(set) var route = Route.brands
    private(set) var notice: String?
    init(session: UFitSessionStore) { brands = .init(session: session) }
    func open(_ id: String) {
        guard case .brands = route, brands.canRead, brands.rows.contains(where: { $0.id == id }) else { return }
        notice = nil; route = .detail(.init(brandID: id, collection: brands))
    }
    func edit() {
        guard case .detail(let detail) = route, detail.canEdit, let reference = detail.document else { return }
        notice = nil; route = .form(.init(detail: detail, reference: reference))
    }
    func history() {
        guard case .detail(let detail) = route, brands.canRead, detail.document != nil else { return }
        route = .history(.init(detail: detail))
    }
    func back() {
        switch route {
        case .brands: break
        case .detail(let detail): detail.cancelLoading(); notice = nil; route = .brands
        case .form(let form): form.cancelLoading(); route = .detail(form.detail)
        case .history(let history): history.cancelLoading(); route = .detail(history.detail)
        }
    }
    func returnToBrands() { notice = nil; route = .brands; Task { await brands.refresh() } }
    func submit(_ form: UFitDistributionFormStore) async {
        guard case .form(let active) = route, active === form else { return }
        guard let result = await form.submit(), case .form(let current) = route, current === form, brands.canRead else { return }
        notice = result.document.current?.id == result.receipt.id ? UFitDistributionCopy.saved : UFitDistributionCopy.superseded
        route = .detail(form.detail)
    }
}
struct UFitDistributionFlowHost: View {
    let store: UFitDistributionFlowStore
    let onClose: () -> Void
    private typealias Copy = UFitDistributionCopy
    var body: some View {
        Group {
            if !store.brands.canRead {
                UFitEmptyState(title: Copy.accessTitle, message: Copy.access, actionTitle: Copy.home, action: onClose)
            } else {
                switch store.route {
                case .brands: UFitDistributionBrandsContent(store: store.brands, onBack: onClose, onOpen: store.open)
                case .detail(let detail):
                    UFitDistributionDetailContent(store: detail, notice: store.notice, onBack: store.back, onEdit: store.edit, onHistory: store.history).id(detail.brandID)
                case .history(let history):
                    UFitDistributionHistoryContent(store: history, onBack: store.back).id(history.detail.brandID)
                case .form(let form):
                    if form.isAvailable { UFitDistributionFormContent(store: form, onBack: store.back, onSubmit: { Task { await store.submit(form) } }) }
                    else { UFitEmptyState(title: Copy.unavailable, message: Copy.missing, actionTitle: Copy.brands, action: store.returnToBrands) }
                }
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}
