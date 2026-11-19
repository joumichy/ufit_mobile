import Foundation
import Observation

@MainActor @Observable
final class UFitCommissionLedgerContext {
  let session: UFitSessionStore
  private(set) var epoch = UUID()
  private(set) var revoked = false
  @ObservationIgnored private let ownerID: String?
  init(session: UFitSessionStore) {
    self.session = session
    ownerID = session.user?.id
  }
  var isOwner: Bool {
    ownerID != nil && session.user?.id == ownerID && session.user?.canAdminister == true
  }
  var canRead: Bool { isOwner && !revoked }
  func revoke() {
    revoked = true
    epoch = UUID()
  }
  func approveFreshRead() {
    if revoked {
      epoch = UUID()
      revoked = false
    }
  }
}

@MainActor @Observable
final class UFitCommissionLedgerStore {
  let context: UFitCommissionLedgerContext
  var search = String()
  var state: UFitCommissionRelease.State?
  var currency: String?
  var visibleRowID: String?
  private(set) var needsRefresh = false
  private(set) var messageAtEnd = false
  @ObservationIgnored private var generation = UUID()
  private var dataEpoch: UUID?
  private var cached = [UFitCommissionEntryDTO]()
  private var rendered = [UFitCommissionEntry]()
  private var metadata: UFitCommissionLedgerPage<UFitCommissionEntryDTO>?
  private var knownCurrencies = [String]()
  private var applied = UFitCommissionLedgerQuery()
  private var loading = false
  private var failure: String?
  private var retryReset = true
  init(context: UFitCommissionLedgerContext) { self.context = context }
  private var visible: Bool { context.canRead && dataEpoch == context.epoch }
  var rows: [UFitCommissionEntry] { visible ? rendered : [] }
  var currencies: [String] { context.canRead ? knownCurrencies : [] }
  var hasLoaded: Bool { visible && metadata != nil }
  var hasMore: Bool { visible && metadata?.nextCursor != nil && !needsRefresh }
  var totalCount: Int? { visible ? metadata?.totalCount : nil }
  var asOf: UFitTimestamp? { visible ? metadata?.asOf : nil }
  var isLoading: Bool { loading && context.isOwner }
  var isFiltered: Bool { selection.isFiltered }
  var message: String? {
    if !context.isOwner || (context.revoked && !loading) { return UFitCommissionLedgerCopy.access }
    if needsRefresh { return UFitCommissionLedgerCopy.changed }
    return failure
  }
  var selection: UFitCommissionLedgerQuery {
    .init(state: state, currency: currency, search: UFitServerTextInput.trimmed(search))
  }
  func entry(_ id: String) -> UFitCommissionEntryDTO? {
    visible ? cached.first { $0.id == id } : nil
  }
  func markChanged(_ entry: UFitCommissionEntryDTO) {
    if let old = self.entry(entry.id), old != entry {
      needsRefresh = true
      messageAtEnd = false
    }
  }
  func cancelLoading() {
    generation = UUID()
    loading = false
  }
  func refresh() async {
    cancelLoading()
    await load()
  }
  func retry() async {
    cancelLoading()
    await load(reset: retryReset || needsRefresh)
  }
  func reset() {
    search = String()
    state = nil
    currency = nil
  }
  func selectionChanged() async {
    guard selection != applied || !hasLoaded else { return }
    let debounce =
      selection.state == applied.state && selection.currency == applied.currency
      && !selection.search.isEmpty
    cancelLoading()
    clear()
    let request = generation
    do { if debounce { try await Task.sleep(for: UFitCommissionLedgerCopy.searchDebounce) } } catch
    { return }
    guard request == generation else { return }
    await load()
  }
  private func clear() {
    visibleRowID = nil
    messageAtEnd = false
    cached = []
    rendered = []
    metadata = nil
    dataEpoch = nil
    needsRefresh = false
    failure = nil
  }
  func load(reset: Bool = true) async {
    guard context.isOwner, !loading, reset || hasMore else { return }
    let request = generation
    let accessEpoch = context.epoch
    let selection = reset ? self.selection : applied
    let previous = reset ? nil : metadata
    let previousItems = reset ? [] : cached
    retryReset = reset
    if reset { clear() }
    loading = true
    failure = nil
    defer { if generation == request { loading = false } }
    do {
      let page = try await context.session.api.fetchAdminCommissions(
        query: selection, cursor: previous?.nextCursor, revision: previous?.revision)
      guard request == generation, context.isOwner, context.epoch == accessEpoch else { return }
      try page.validateAppend(
        existing: previousItems, expectedLimit: UFitCommissionLedgerContract.limit,
        expectedRevision: previous?.revision)
      guard previous == nil || previous?.totalCount == page.totalCount else {
        throw UFitWorkspaceFinanceFailure.page
      }
      let items = previousItems + page.items
      let values = try items.map { try $0.presentation() }
      context.approveFreshRead()
      dataEpoch = context.epoch
      cached = items
      rendered = values
      metadata = page
      knownCurrencies = page.currencies
      applied = selection
      needsRefresh = false
    } catch {
      guard request == generation, context.isOwner, context.epoch == accessEpoch else { return }
      if UFitCommissionLedgerCopy.isRevoked(error) {
        context.revoke()
        clear()
      }
      if UFitCommissionLedgerCopy.isChanged(error) {
        needsRefresh = true
        retryReset = true
      }
      messageAtEnd = !reset
      failure = UFitCommissionLedgerCopy.message(error)
    }
  }
}

@MainActor @Observable
final class UFitCommissionLedgerDetailStore {
  let id: String
  let list: UFitCommissionLedgerStore
  private var cached: UFitCommissionLedgerDetail?
  private var rendered: UFitCommissionEntry?
  private var renderedRule: UFitCommissionRuleSnapshot?
  private var dataEpoch: UUID?
  private var loading = false
  private var failure: String?
  private var missing = false
  @ObservationIgnored private var generation = UUID()
  init(id: String, list: UFitCommissionLedgerStore) {
    self.id = id
    self.list = list
  }
  var document: UFitCommissionLedgerDetail? {
    list.context.canRead && dataEpoch == list.context.epoch ? cached : nil
  }
  var presentation: UFitCommissionEntry? { document == nil ? nil : rendered }
  var rulePresentation: UFitCommissionRuleSnapshot? { document == nil ? nil : renderedRule }
  var isLoading: Bool { loading && list.context.isOwner }
  var unavailable: Bool { missing && !loading }
  var message: String? {
    if !list.context.isOwner || (list.context.revoked && !loading) {
      return UFitCommissionLedgerCopy.access
    }
    return failure
  }
  func cancelLoading() {
    generation = UUID()
    loading = false
  }
  func report(_ error: Error) { failure = UFitCommissionLedgerCopy.message(error) }
  func load() async {
    let context = list.context
    guard context.isOwner, !loading else { return }
    let request = generation
    let accessEpoch = context.epoch
    loading = true
    failure = nil
    missing = false
    cached = nil
    rendered = nil
    renderedRule = nil
    dataEpoch = nil
    defer { if request == generation { loading = false } }
    do {
      let document = try await context.session.api.fetchCommissionLedgerDetail(id)
      let value = try document.commission.presentation()
      let rule = try document.rule?.presentation()
      guard request == generation, context.isOwner, context.epoch == accessEpoch else { return }
      context.approveFreshRead()
      dataEpoch = context.epoch
      cached = document
      rendered = value
      renderedRule = rule
      list.markChanged(document.commission)
    } catch {
      guard request == generation, context.isOwner, context.epoch == accessEpoch else { return }
      if UFitCommissionLedgerCopy.isRevoked(error) { context.revoke() }
      missing = UFitCommissionLedgerCopy.isMissing(error)
      if !missing { failure = UFitCommissionLedgerCopy.message(error) }
    }
  }
}

@MainActor @Observable
final class UFitCommissionRelatedReturnsStore {
  var visibleRowID: String?
  let commissionID: String
  let context: UFitCommissionLedgerContext
  private var cached = [UFitCommissionRelatedReturn]()
  private var metadata: UFitCommissionLedgerPage<UFitCommissionRelatedReturn>?
  private var dataEpoch: UUID?
  private var loading = false
  private var failure: String?
  private var retryReset = true
  private(set) var needsRefresh = false
  private(set) var messageAtEnd = false
  @ObservationIgnored private var generation = UUID()
  init(commissionID: String, context: UFitCommissionLedgerContext) {
    self.commissionID = commissionID
    self.context = context
  }
  private var visible: Bool { context.canRead && dataEpoch == context.epoch }
  var rows: [UFitCommissionRelatedReturn] { visible ? cached : [] }
  var hasLoaded: Bool { visible && metadata != nil }
  var hasMore: Bool { visible && metadata?.nextCursor != nil && !needsRefresh }
  var asOf: UFitTimestamp? { visible ? metadata?.asOf : nil }
  var isLoading: Bool { loading && context.isOwner }
  var message: String? {
    if !context.isOwner || (context.revoked && !loading) {
      return UFitCommissionLedgerCopy.relatedAccess
    }
    return needsRefresh ? UFitCommissionLedgerCopy.relatedChanged : failure
  }
  func markChanged() {
    needsRefresh = true
    messageAtEnd = false
  }
  func report(_ error: Error) {
    failure = UFitCommissionLedgerCopy.message(error, resource: .relatedReturns)
  }
  func cancelLoading() {
    generation = UUID()
    loading = false
  }
  func retry() async {
    cancelLoading()
    await load(reset: retryReset || needsRefresh)
  }
  func refresh() async {
    cancelLoading()
    await load()
  }
  func load(reset: Bool = true) async {
    guard context.isOwner, !loading, reset || hasMore else { return }
    let request = generation
    let accessEpoch = context.epoch
    let previous = reset ? nil : metadata
    let previousItems = reset ? [] : cached
    retryReset = reset
    if reset {
      visibleRowID = nil
      messageAtEnd = false
      cached = []
      metadata = nil
      dataEpoch = nil
      needsRefresh = false
    }
    loading = true
    failure = nil
    defer { if request == generation { loading = false } }
    do {
      let page = try await context.session.api.fetchCommissionRelatedReturns(
        commissionID, cursor: previous?.nextCursor, revision: previous?.revision)
      guard request == generation, context.isOwner, context.epoch == accessEpoch else { return }
      try page.validateAppend(
        existing: previousItems, expectedLimit: UFitCommissionLedgerContract.limit,
        expectedRevision: previous?.revision)
      guard previous == nil || previous?.totalCount == page.totalCount else {
        throw UFitWorkspaceFinanceFailure.page
      }
      context.approveFreshRead()
      dataEpoch = context.epoch
      cached = previousItems + page.items
      metadata = page
      needsRefresh = false
    } catch {
      guard request == generation, context.isOwner, context.epoch == accessEpoch else { return }
      if UFitCommissionLedgerCopy.isRevoked(error) {
        context.revoke()
        cached = []
        metadata = nil
        dataEpoch = nil
      }
      if UFitCommissionLedgerCopy.isChanged(error) {
        needsRefresh = true
        retryReset = true
      }
      messageAtEnd = !reset
      failure = UFitCommissionLedgerCopy.message(error, resource: .relatedReturns)
    }
  }
}
