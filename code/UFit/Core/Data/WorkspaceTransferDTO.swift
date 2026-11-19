import Foundation

struct UFitWorkspaceTransferGroup: Hashable { let currency: String; let liveMode: Bool }
struct UFitWorkspaceTransferEntry: Decodable, Identifiable {
    enum Kind: String, Decodable { case transfer, reversal }
    let id: String; let kind: Kind; let amount: Int; let currency: String; let liveMode: Bool
    let createdAt: UFitTimestamp; let recordedAt: UFitTimestamp
    let orderNumber: String; let brandName: String
    @UFitRequiredNullable var itemName: String?
    let receiptId: String
    @UFitRequiredNullable var originalTransferId: String?
    var group: UFitWorkspaceTransferGroup { .init(currency: currency, liveMode: liveMode) }
    var signedAmount: Int { kind == .transfer ? amount : .zero - amount }
}
struct UFitWorkspaceTransferCurrency: Decodable, Identifiable, Equatable {
    let currency: String; let liveMode: Bool
    let transferred: Int; let recovered: Int; let netTransferred: Int
    let transferCount: Int; let reversalCount: Int
    var id: UFitWorkspaceTransferGroup { .init(currency: currency, liveMode: liveMode) }
}
struct UFitWorkspaceTransferPage: Decodable {
    let profileId: String; let kind: UFitConnectKind; let asOf: UFitTimestamp
    let limit: Int; let totalCount: Int
    @UFitRequiredNullable var nextCursor: String?
    let revision: String; let currencies: [UFitWorkspaceTransferCurrency]; let items: [UFitWorkspaceTransferEntry]
    func validate(workspace: UFitWorkspaceReference) throws {
        let invalid = UFitWorkspaceTransferFailure.document
        guard profileId == workspace.profileID, UFitPaymentAllocationHTTP.validID(profileId),
              kind == (workspace.isCreator ? .creator : .brand), limit == UFitWorkspaceTransfersHTTP.limit,
              UFitWorkspaceFinanceContract.integer(totalCount), items.count <= limit, items.count <= totalCount,
              revision.range(of: UFitWorkspaceTransfersHTTP.revisionPattern, options: .regularExpression) != nil,
              Set(currencies.map(\.id)).count == currencies.count,
              Set(items.map(\.id)).count == items.count, Set(items.map(\.receiptId)).count == items.count,
              UFitWorkspaceFinanceContract.sum(currencies.flatMap { [$0.transferCount, $0.reversalCount] }) == totalCount,
              nextCursor == nil || (items.count == limit && nextCursor == items.last?.id) else { throw invalid }
        for group in currencies {
            guard UFitWorkspaceFinanceContract.currency(group.currency),
                  [group.transferred, group.recovered, group.netTransferred, group.transferCount, group.reversalCount].allSatisfy(UFitWorkspaceFinanceContract.integer),
                  group.transferred > .zero, group.transferCount > .zero,
                  group.transferred - group.recovered == group.netTransferred else { throw invalid }
        }
        for row in items {
            guard UFitPaymentAllocationHTTP.validID(row.id), UFitReturnContract.money(row.amount), row.amount > .zero,
                  UFitReturnContract.nonempty(row.orderNumber), UFitReturnContract.nonempty(row.brandName),
                  currencies.contains(where: { $0.id == row.group }),
                  workspace.isCreator ? row.itemName.map(UFitReturnContract.nonempty) == true : row.itemName == nil else { throw invalid }
            if row.kind == .transfer {
                guard row.receiptId.range(of: UFitPaymentDisbursementHTTP.transferPattern, options: .regularExpression) != nil,
                      row.originalTransferId == nil else { throw invalid }
            } else {
                guard row.receiptId.range(of: UFitPaymentDisbursementHTTP.reversalPattern, options: .regularExpression) != nil,
                      row.originalTransferId?.range(of: UFitPaymentDisbursementHTTP.transferPattern, options: .regularExpression) != nil else { throw invalid }
            }
        }
    }
    func validateAppend(existing: [UFitWorkspaceTransferEntry], previous: UFitWorkspaceTransferPage?) throws {
        let invalid = UFitWorkspaceTransferFailure.document
        guard previous == nil || (previous?.revision == revision && previous?.currencies == currencies && previous?.totalCount == totalCount),
              Set(existing.map(\.id)).isDisjoint(with: Set(items.map(\.id))),
              Set(existing.map(\.receiptId)).isDisjoint(with: Set(items.map(\.receiptId))),
              let count = UFitWorkspaceFinanceContract.sum([existing.count, items.count]), count <= totalCount,
              nextCursor == nil ? count == totalCount : count < totalCount else { throw invalid }
        let combined = existing + items
        for group in currencies {
            let rows = combined.filter { $0.group == group.id }
            guard let transferred = UFitWorkspaceFinanceContract.sum(rows.filter { $0.kind == .transfer }.map(\.amount)),
                  let recovered = UFitWorkspaceFinanceContract.sum(rows.filter { $0.kind == .reversal }.map(\.amount)),
                  transferred <= group.transferred, recovered <= group.recovered,
                  rows.filter({ $0.kind == .transfer }).count <= group.transferCount,
                  rows.filter({ $0.kind == .reversal }).count <= group.reversalCount,
                  nextCursor != nil || (transferred == group.transferred && recovered == group.recovered
                    && rows.filter({ $0.kind == .transfer }).count == group.transferCount
                    && rows.filter({ $0.kind == .reversal }).count == group.reversalCount) else { throw invalid }
        }
    }
}
