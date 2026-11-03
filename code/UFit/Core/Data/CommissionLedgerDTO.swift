import Foundation

enum UFitCommissionLedgerContract {
  static let limit = 20
  static let maximumLimit = 50
  static let revisionPattern = #"^[a-f0-9]{32}$"#
  static let changedCode = "commission_ledger_changed"
  static let missingCode = "commission_ledger_not_found"
}
protocol UFitCommissionPageItem: Decodable, Identifiable where ID == String {
  var currency: String { get }
}
extension UFitCommissionEntryDTO: UFitCommissionPageItem {}

struct UFitCommissionLedgerPage<Row: UFitCommissionPageItem>: Decodable {
  let items: [Row]
  let limit: Int
  let totalCount: Int
  let nextCursor: String?
  let revision: String
  let asOf: UFitTimestamp
  let currencies: [String]
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case items, limit, totalCount, nextCursor, revision, asOf, currencies
  }
  init(from decoder: Decoder) throws {
    try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitWorkspaceFinanceFailure.page)
    let value = try decoder.container(keyedBy: CodingKeys.self)
    items = try value.decode([Row].self, forKey: .items)
    limit = try value.decode(Int.self, forKey: .limit)
    totalCount = try value.decode(Int.self, forKey: .totalCount)
    nextCursor = try value.decodeIfPresent(String.self, forKey: .nextCursor)
    revision = try value.decode(String.self, forKey: .revision)
    asOf = try value.decode(UFitTimestamp.self, forKey: .asOf)
    currencies = try value.decode([String].self, forKey: .currencies)
    guard
      (UFitWorkspaceFinanceContract.single...UFitCommissionLedgerContract.maximumLimit).contains(
        limit),
      UFitWorkspaceFinanceContract.integer(totalCount), items.count <= limit,
      items.count <= totalCount,
      Set(items.map(\.id)).count == items.count,
      items.allSatisfy({ UUID(uuidString: $0.id) != nil && currencies.contains($0.currency) }),
      Set(currencies).count == currencies.count,
      currencies.allSatisfy(UFitWorkspaceFinanceContract.currency),
      revision.range(of: UFitCommissionLedgerContract.revisionPattern, options: .regularExpression)
        != nil,
      nextCursor == nil || (!items.isEmpty && nextCursor == items.last?.id)
    else { throw UFitWorkspaceFinanceFailure.page }
  }
  func validateAppend(existing: [Row], expectedLimit: Int, expectedRevision: String?) throws {
    guard limit == expectedLimit, expectedRevision == nil || expectedRevision == revision,
      Set(existing.map(\.id)).isDisjoint(with: Set(items.map(\.id))),
      let count = UFitWorkspaceFinanceContract.sum([existing.count, items.count]),
      count <= totalCount,
      nextCursor == nil ? count == totalCount : count < totalCount
    else { throw UFitWorkspaceFinanceFailure.page }
  }
}

struct UFitCommissionLedgerDetail: Decodable {
  struct Rule: Decodable {
    let id: String
    let scopeId: String
    let revision: Int
    let creatorGradeCode: String
    let baseRateBps: Int
    let bonusRateBps: Int
    let maxRateBps: Int?
    private enum CodingKeys: String, CodingKey, CaseIterable {
      case id, scopeId, revision, creatorGradeCode, baseRateBps, bonusRateBps, maxRateBps
    }
    init(from decoder: Decoder) throws {
      try UFitStrictDecoding.keys(
        decoder, CodingKeys.self, failure: UFitWorkspaceFinanceFailure.document)
      let value = try decoder.container(keyedBy: CodingKeys.self)
      id = try value.decode(String.self, forKey: .id)
      scopeId = try value.decode(String.self, forKey: .scopeId)
      revision = try value.decode(Int.self, forKey: .revision)
      creatorGradeCode = try value.decode(String.self, forKey: .creatorGradeCode)
      baseRateBps = try value.decode(Int.self, forKey: .baseRateBps)
      bonusRateBps = try value.decode(Int.self, forKey: .bonusRateBps)
      maxRateBps = try value.decodeIfPresent(Int.self, forKey: .maxRateBps)
      guard UUID(uuidString: id) != nil, UUID(uuidString: scopeId) != nil,
        revision >= UFitWorkspaceFinanceContract.single,
        !creatorGradeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        [baseRateBps, bonusRateBps].allSatisfy({
          (.zero...UFitWorkspaceFinanceContract.basisPoints).contains($0)
        }),
        maxRateBps == nil
          || (.zero...UFitWorkspaceFinanceContract.basisPoints).contains(maxRateBps!)
      else { throw UFitWorkspaceFinanceFailure.document }
    }
  }
  let commission: UFitCommissionEntryDTO
  let orderId: String
  let relatedReturnCount: Int
  let rule: Rule?
  let asOf: UFitTimestamp
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case commission, orderId, relatedReturnCount, rule, asOf
  }
  init(from decoder: Decoder) throws {
    try UFitStrictDecoding.keys(
      decoder, CodingKeys.self, failure: UFitWorkspaceFinanceFailure.document)
    let value = try decoder.container(keyedBy: CodingKeys.self)
    commission = try value.decode(UFitCommissionEntryDTO.self, forKey: .commission)
    orderId = try value.decode(String.self, forKey: .orderId)
    relatedReturnCount = try value.decode(Int.self, forKey: .relatedReturnCount)
    rule = try value.decodeIfPresent(Rule.self, forKey: .rule)
    asOf = try value.decode(UFitTimestamp.self, forKey: .asOf)
    guard UUID(uuidString: orderId) != nil, UFitWorkspaceFinanceContract.integer(relatedReturnCount)
    else { throw UFitWorkspaceFinanceFailure.document }
    if let rule {
      let cap = rule.maxRateBps ?? UFitWorkspaceFinanceContract.basisPoints
      guard min(rule.baseRateBps + rule.bonusRateBps, cap) == commission.rateBps else {
        throw UFitWorkspaceFinanceFailure.document
      }
    }
  }
}

struct UFitCommissionRelatedReturn: UFitCommissionPageItem {
  let id: String
  let status: UFitReturnStatus
  let version: Int
  let requestedAt: UFitTimestamp
  let quantity: Int
  let adjustedAmount: Int
  let currency: String
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case id, status, version, requestedAt, quantity, adjustedAmount, currency
  }
  init(from decoder: Decoder) throws {
    try UFitStrictDecoding.keys(
      decoder, CodingKeys.self, failure: UFitWorkspaceFinanceFailure.document)
    let value = try decoder.container(keyedBy: CodingKeys.self)
    id = try value.decode(String.self, forKey: .id)
    status = try value.decode(UFitReturnStatus.self, forKey: .status)
    version = try value.decode(Int.self, forKey: .version)
    requestedAt = try value.decode(UFitTimestamp.self, forKey: .requestedAt)
    quantity = try value.decode(Int.self, forKey: .quantity)
    adjustedAmount = try value.decode(Int.self, forKey: .adjustedAmount)
    currency = try value.decode(String.self, forKey: .currency)
    guard UUID(uuidString: id) != nil, version >= UFitWorkspaceFinanceContract.single,
      quantity >= UFitWorkspaceFinanceContract.single,
      [version, quantity, adjustedAmount].allSatisfy(UFitWorkspaceFinanceContract.integer),
      UFitWorkspaceFinanceContract.currency(currency)
    else { throw UFitWorkspaceFinanceFailure.document }
  }
}
