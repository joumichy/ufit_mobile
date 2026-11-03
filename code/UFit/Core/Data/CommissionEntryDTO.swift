import Foundation

struct UFitCommissionEntryDTO: Decodable, Identifiable, Equatable {
  struct Creator: Decodable, Equatable {
    let id: String
    let name: String
    private enum CodingKeys: String, CodingKey, CaseIterable { case id, name }
    init(from decoder: Decoder) throws {
      try UFitStrictDecoding.keys(
        decoder, CodingKeys.self, failure: UFitWorkspaceFinanceFailure.document)
      let value = try decoder.container(keyedBy: CodingKeys.self)
      id = try value.decode(String.self, forKey: .id)
      name = try value.decode(String.self, forKey: .name)
      guard UUID(uuidString: id) != nil, UFitCommissionEntryDTO.text(name) else {
        throw UFitWorkspaceFinanceFailure.document
      }
    }
  }
  struct Sale: Decodable, Equatable {
    let orderNumber: String
    let productName: String
    let brandName: String
    let quantity: Int
    private enum CodingKeys: String, CodingKey, CaseIterable {
      case orderNumber, productName, brandName, quantity
    }
    init(from decoder: Decoder) throws {
      try UFitStrictDecoding.keys(
        decoder, CodingKeys.self, failure: UFitWorkspaceFinanceFailure.document)
      let value = try decoder.container(keyedBy: CodingKeys.self)
      orderNumber = try value.decode(String.self, forKey: .orderNumber)
      productName = try value.decode(String.self, forKey: .productName)
      brandName = try value.decode(String.self, forKey: .brandName)
      quantity = try value.decode(Int.self, forKey: .quantity)
      guard [orderNumber, productName, brandName].allSatisfy(UFitCommissionEntryDTO.text),
        UFitWorkspaceFinanceContract.integer(quantity),
        quantity >= UFitWorkspaceFinanceContract.single
      else { throw UFitWorkspaceFinanceFailure.document }
    }
  }
  let id: String
  let orderItemId: String
  let brandId: String
  let sourceOutfitId: String
  let status: UFitCommissionState
  let currency: String
  let baseAmount: Int
  let rateBps: Int
  let originalAmount: Int
  let adjustedAmount: Int
  let netAmount: Int
  let paidAdjustmentAmount: Int
  let createdAt: UFitTimestamp
  let release: UFitCommissionRelease
  let creator: Creator
  let sale: Sale
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case id, orderItemId, brandId, sourceOutfitId, status, currency, baseAmount, rateBps,
      originalAmount, adjustedAmount, netAmount, paidAdjustmentAmount, createdAt, release, creator,
      sale
  }
  init(from decoder: Decoder) throws {
    try UFitStrictDecoding.keys(
      decoder, CodingKeys.self, failure: UFitWorkspaceFinanceFailure.document)
    let value = try decoder.container(keyedBy: CodingKeys.self)
    id = try value.decode(String.self, forKey: .id)
    orderItemId = try value.decode(String.self, forKey: .orderItemId)
    brandId = try value.decode(String.self, forKey: .brandId)
    sourceOutfitId = try value.decode(String.self, forKey: .sourceOutfitId)
    status = try value.decode(UFitCommissionState.self, forKey: .status)
    currency = try value.decode(String.self, forKey: .currency)
    baseAmount = try value.decode(Int.self, forKey: .baseAmount)
    rateBps = try value.decode(Int.self, forKey: .rateBps)
    originalAmount = try value.decode(Int.self, forKey: .originalAmount)
    adjustedAmount = try value.decode(Int.self, forKey: .adjustedAmount)
    netAmount = try value.decode(Int.self, forKey: .netAmount)
    paidAdjustmentAmount = try value.decode(Int.self, forKey: .paidAdjustmentAmount)
    createdAt = try value.decode(UFitTimestamp.self, forKey: .createdAt)
    release = try value.decode(UFitCommissionRelease.self, forKey: .release)
    creator = try value.decode(Creator.self, forKey: .creator)
    sale = try value.decode(Sale.self, forKey: .sale)
    guard [id, orderItemId, brandId, sourceOutfitId].allSatisfy({ UUID(uuidString: $0) != nil }),
      UFitWorkspaceFinanceContract.currency(currency),
      [baseAmount, rateBps, originalAmount, adjustedAmount, netAmount, paidAdjustmentAmount]
        .allSatisfy(UFitWorkspaceFinanceContract.integer),
      rateBps <= UFitWorkspaceFinanceContract.basisPoints,
      UFitWorkspaceFinanceContract.sum([adjustedAmount, netAmount]) == originalAmount,
      release.status == status,
      status == .paid ? paidAdjustmentAmount == adjustedAmount : paidAdjustmentAmount == .zero
    else { throw UFitWorkspaceFinanceFailure.document }
  }
  private static func text(_ value: String) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
