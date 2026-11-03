import Foundation

private enum CommissionLedgerHTTP {
  static let get = "GET"
  static let admin = "admin/commissions"
  static let creator = "creators/me/commissions"
  static let separator = "/"
  static let returns = "/returns"
  static let limit = "limit"
  static let cursor = "cursor"
  static let revision = "revision"
  static let state = "state"
  static let currency = "currency"
  static let search = "search"
}
struct UFitCommissionLedgerQuery: Equatable {
  var state: UFitCommissionRelease.State?
  var currency: String?
  var search = String()
  var isFiltered: Bool {
    state != nil || currency != nil || !UFitServerTextInput.trimmed(search).isEmpty
  }
}
extension UFitAPIClient {
  func fetchAdminCommissions(query: UFitCommissionLedgerQuery, cursor: String?, revision: String?)
    async throws -> UFitCommissionLedgerPage<UFitCommissionEntryDTO>
  {
    var items = commissionLedgerQuery(cursor: cursor, revision: revision)
    if let state = query.state {
      items.append(URLQueryItem(name: CommissionLedgerHTTP.state, value: state.rawValue))
    }
    if let currency = query.currency {
      items.append(URLQueryItem(name: CommissionLedgerHTTP.currency, value: currency))
    }
    let search = UFitServerTextInput.trimmed(query.search)
    if !search.isEmpty {
      items.append(URLQueryItem(name: CommissionLedgerHTTP.search, value: search))
    }
    return try await send(
      CommissionLedgerHTTP.get, path: CommissionLedgerHTTP.admin, query: items, requiresAuth: true,
      cachePolicy: .reloadIgnoringLocalCacheData)
  }
  func fetchCreatorCommissions(
    creatorID: String, state: UFitCommissionRelease.State?, cursor: String?, revision: String?
  ) async throws -> UFitCommissionLedgerPage<UFitCommissionEntryDTO> {
    var query = commissionLedgerQuery(cursor: cursor, revision: revision)
    if let state {
      query.append(URLQueryItem(name: CommissionLedgerHTTP.state, value: state.rawValue))
    }
    let page: UFitCommissionLedgerPage<UFitCommissionEntryDTO> = try await send(
      CommissionLedgerHTTP.get, path: CommissionLedgerHTTP.creator,
      query: query, requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
    guard page.items.allSatisfy({ $0.creator.id == creatorID }) else {
      throw UFitWorkspaceFinanceFailure.document
    }
    return page
  }
  func fetchCommissionLedgerDetail(_ id: String) async throws -> UFitCommissionLedgerDetail {
    let document: UFitCommissionLedgerDetail = try await send(
      CommissionLedgerHTTP.get,
      path: CommissionLedgerHTTP.admin + CommissionLedgerHTTP.separator + id,
      requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
    guard document.commission.id == id else { throw UFitWorkspaceFinanceFailure.document }
    return document
  }
  func fetchCommissionRelatedReturns(_ id: String, cursor: String?, revision: String?) async throws
    -> UFitCommissionLedgerPage<UFitCommissionRelatedReturn>
  {
    try await send(
      CommissionLedgerHTTP.get,
      path: CommissionLedgerHTTP.admin + CommissionLedgerHTTP.separator + id
        + CommissionLedgerHTTP.returns,
      query: commissionLedgerQuery(cursor: cursor, revision: revision), requiresAuth: true,
      cachePolicy: .reloadIgnoringLocalCacheData)
  }
}
private func commissionLedgerQuery(cursor: String?, revision: String?) -> [URLQueryItem] {
  var result = [
    URLQueryItem(
      name: CommissionLedgerHTTP.limit, value: String(UFitCommissionLedgerContract.limit))
  ]
  if let cursor { result.append(URLQueryItem(name: CommissionLedgerHTTP.cursor, value: cursor)) }
  if let revision {
    result.append(URLQueryItem(name: CommissionLedgerHTTP.revision, value: revision))
  }
  return result
}
