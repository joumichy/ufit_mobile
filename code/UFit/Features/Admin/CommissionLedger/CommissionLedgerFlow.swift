import Observation
import SwiftUI

@MainActor @Observable
final class UFitCommissionLedgerFlowStore {
  enum Route {
    case list
    case detail(UFitCommissionLedgerDetailStore)
    case returns(UFitCommissionRelatedReturnsStore)
    case order(UFitBrandOrderStore)
    case orderReturn(UFitReturnDetailStore, UFitCommissionRelatedReturn)
  }
  let list: UFitCommissionLedgerStore
  private(set) var route = Route.list
  @ObservationIgnored private var history = [Route]()
  init(session: UFitSessionStore) { list = .init(context: .init(session: session)) }
  var canGoBack: Bool { !history.isEmpty }
  func cancelLoading() {
    switch route {
    case .list: list.cancelLoading()
    case .detail(let detail): detail.cancelLoading()
    case .returns(let returns): returns.cancelLoading()
    case .order, .orderReturn: break
    }
  }
  func back() {
    guard let previous = history.popLast() else { return }
    if case .orderReturn(let detail, let original) = route,
      let current = detail.detail, current.version != original.version,
      case .returns(let collection) = previous
    {
      collection.markChanged()
    }
    cancelLoading()
    route = previous
  }
  func open(_ id: String) {
    guard case .list = route, list.context.canRead, list.entry(id) != nil else { return }
    history.append(route)
    route = .detail(.init(id: id, list: list))
  }
  func showOrder() {
    guard case .detail(let detail) = route, let document = detail.document else { return }
    do {
      let collection = try UFitBrandOrdersStore(
        administrating: document.commission.brandId,
        brandName: document.commission.sale.brandName, session: list.context.session)
      let order = try UFitBrandOrderStore(id: document.orderId, list: collection)
      history.append(route)
      route = .order(order)
    } catch { detail.report(error) }
  }
  func showReturns() {
    guard case .detail(let detail) = route, let document = detail.document,
      document.relatedReturnCount > .zero
    else { return }
    history.append(route)
    route = .returns(.init(commissionID: detail.id, context: list.context))
  }
  func openReturn(_ reference: UFitCommissionRelatedReturn) {
    guard case .returns(let collection) = route, list.context.canRead,
      collection.rows.contains(where: { $0.id == reference.id })
    else { return }
    do {
      let returns = try UFitReturnsStore(
        scope: .administrator, context: UFitCommissionLedgerCopy.title,
        session: list.context.session)
      let detail = try UFitReturnDetailStore(id: reference.id, list: returns)
      history.append(route)
      route = .orderReturn(detail, reference)
    } catch { collection.report(error) }
  }
}

struct UFitCommissionLedgerFlowHost: View {
  let store: UFitCommissionLedgerFlowStore
  let onClose: () -> Void
  private var onBack: () -> Void { { if store.canGoBack { store.back() } else { onClose() } } }
  var body: some View {
    switch store.route {
    case .list: UFitCommissionLedgerHost(store: store.list, onBack: onBack, onOpen: store.open)
    case .detail(let detail):
      UFitCommissionLedgerDetailHost(
        store: detail, onBack: onBack, onOrder: store.showOrder, onReturns: store.showReturns
      ).id(detail.id)
    case .returns(let returns):
      UFitCommissionRelatedReturnsHost(store: returns, onBack: onBack, onOpen: store.openReturn)
    case .order(let order): UFitBrandOrderHost(store: order, onBack: onBack)
    case .orderReturn(let detail, _): UFitReturnDetailHost(store: detail, onBack: onBack)
    }
  }
}

struct UFitCommissionLedgerHost: View {
  @Bindable var store: UFitCommissionLedgerStore
  let onBack: () -> Void
  let onOpen: (String) -> Void
  var body: some View {
    UFitCommissionLedgerContent(
      rows: store.rows, visibleRowID: $store.visibleRowID, messageAtEnd: store.messageAtEnd,
      search: $store.search, state: $store.state, currency: $store.currency,
      currencies: store.currencies, totalCount: store.totalCount, asOf: store.asOf,
      isLoading: store.isLoading,
      hasLoaded: store.hasLoaded, hasMore: store.hasMore, isFiltered: store.isFiltered,
      message: store.message,
      onBack: onBack, onRefresh: { Task { await store.refresh() } },
      onRetry: { Task { await store.retry() } }, onReset: store.reset, onOpen: onOpen,
      onMore: { Task { await store.load(reset: false) } }
    )
    .task { if !store.hasLoaded { await store.load() } }
    .onChange(of: store.selection) { _, _ in Task { await store.selectionChanged() } }
    .onDisappear { store.cancelLoading() }
  }
}

struct UFitCommissionLedgerDetailHost: View {
  let store: UFitCommissionLedgerDetailStore
  let onBack: () -> Void
  let onOrder: () -> Void
  let onReturns: () -> Void
  var body: some View {
    UFitCommissionLedgerDetailContent(
      document: store.document, entry: store.presentation, rulePresentation: store.rulePresentation,
      isLoading: store.isLoading, unavailable: store.unavailable, message: store.message,
      onBack: onBack, onRefresh: { Task { await store.load() } },
      onRetry: { Task { await store.load() } }, onOrder: onOrder, onReturns: onReturns
    )
    .task { await store.load() }.onDisappear { store.cancelLoading() }
  }
}

struct UFitCommissionRelatedReturnsHost: View {
  @Bindable var store: UFitCommissionRelatedReturnsStore
  let onBack: () -> Void
  let onOpen: (UFitCommissionRelatedReturn) -> Void
  var body: some View {
    UFitCommissionRelatedReturnsContent(
      rows: store.rows, visibleRowID: $store.visibleRowID, messageAtEnd: store.messageAtEnd,
      hasLoaded: store.hasLoaded, isLoading: store.isLoading,
      hasMore: store.hasMore, asOf: store.asOf, message: store.message, onBack: onBack,
      onRefresh: { Task { await store.refresh() } }, onRetry: { Task { await store.retry() } },
      onMore: { Task { await store.load(reset: false) } }, onOpen: onOpen
    )
    .task { if !store.hasLoaded { await store.load() } }.onDisappear { store.cancelLoading() }
  }
}
