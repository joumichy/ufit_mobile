import Foundation

struct UFitPaymentAllocationDocument: Decodable {
    enum State: String, Decodable { case notPrepared = "not_prepared", blocked, recorded }
    enum BlockReason: String, Decodable {
        case terms = "purchased_terms_missing", settlement = "capture_receipt_missing"
        case fulfillment = "fulfillment_missing", basis = "allocation_basis_invalid"
    }
    struct Context: Decodable {
        struct Brand: Decodable { let id: String; let name: String }
        struct CreatorItem: Decodable, Identifiable {
            let commissionId: String; let creatorId: String; let creatorName: String; let itemName: String
            var id: String { commissionId }
        }
        let orderNumber: String; let brand: Brand; let creatorItems: [CreatorItem]
        @UFitRequiredNullable var liveMode: Bool?
    }
    let paymentId: String; let orderId: String; let asOf: UFitTimestamp; let context: Context; let state: State
    @UFitRequiredNullable var blockReason: BlockReason?
    @UFitRequiredNullable var plan: UFitPaymentAllocationPlan?
    func validate(reference: UFitPaymentSettlementDocument, brandID: String) throws {
        let invalid = UFitPaymentAllocationFailure.document
        guard paymentId == reference.payment.id, orderId == reference.payment.orderId,
              context.orderNumber == reference.payment.orderNumber, context.brand.id == brandID,
              [paymentId, orderId, brandID].allSatisfy(UFitPaymentAllocationHTTP.validID), UFitReturnContract.nonempty(context.brand.name),
              (state == .recorded) == (plan != nil), (state == .blocked) == (blockReason != nil),
              Set(context.creatorItems.map(\.id)).count == context.creatorItems.count else { throw invalid }
        for item in context.creatorItems {
            guard [item.commissionId, item.creatorId].allSatisfy(UFitPaymentAllocationHTTP.validID),
                  UFitReturnContract.nonempty(item.creatorName), UFitReturnContract.nonempty(item.itemName) else { throw invalid }
        }
        if let receipt = reference.receipt { guard context.liveMode == receipt.liveMode else { throw invalid } }
        guard let plan else { guard context.creatorItems.isEmpty else { throw invalid }; return }
        guard context.liveMode != nil else { throw invalid }
        try plan.validate(reference: reference, brandID: brandID)
        let creators = plan.lines.filter { $0.recipient.kind == .creator }
        guard context.creatorItems.count == creators.count,
              creators.allSatisfy({ line in context.creatorItems.contains(where: { $0.commissionId == line.recipient.commissionID && $0.creatorId == line.recipient.beneficiaryID }) }) else { throw invalid }
    }
}
enum UFitPaymentAllocationRecipient: Decodable, Hashable {
    enum Kind: String, Decodable { case brand, creator, platform }
    private enum CodingKeys: String, CodingKey { case kind, beneficiaryId, commissionId }
    case brand(String), creator(beneficiaryID: String, commissionID: String), platform
    var kind: Kind { switch self { case .brand: .brand; case .creator: .creator; case .platform: .platform } }
    var beneficiaryID: String? { switch self { case .brand(let id), .creator(let id, _): id; case .platform: nil } }
    var commissionID: String? { if case .creator(_, let id) = self { id } else { nil } }
    var key: String {
        let separator = UFitPaymentAllocationHTTP.separator
        switch self {
        case .platform: return kind.rawValue
        case .brand(let id): return kind.rawValue + separator + id
        case .creator(let id, let commission): return kind.rawValue + separator + id + separator + commission
        }
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try values.decode(Kind.self, forKey: .kind)
        switch kind {
        case .platform:
            guard values.contains(.beneficiaryId), try values.decodeNil(forKey: .beneficiaryId), !values.contains(.commissionId) else { throw UFitPaymentAllocationFailure.document }
            self = .platform
        case .brand, .creator:
            let beneficiary = try values.decode(String.self, forKey: .beneficiaryId)
            guard UFitPaymentAllocationHTTP.validID(beneficiary) else { throw UFitPaymentAllocationFailure.document }
            if kind == .creator {
                let commission = try values.decode(String.self, forKey: .commissionId)
                guard UFitPaymentAllocationHTTP.validID(commission) else { throw UFitPaymentAllocationFailure.document }
                self = .creator(beneficiaryID: beneficiary, commissionID: commission)
            } else {
                guard !values.contains(.commissionId) else { throw UFitPaymentAllocationFailure.document }; self = .brand(beneficiary)
            }
        }
    }
}
struct UFitPaymentAllocationPlan: Decodable {
    struct Line: Decodable, Identifiable {
        let recipient: UFitPaymentAllocationRecipient
        let presentmentAmount: Int; let grossAmount: Int; let feeAmount: Int; let netAmount: Int
        var id: String { recipient.key }
    }
    let paymentId: String; let orderId: String; let brandId: String; let policyId: String
    let algorithm: String; let chargeId: String; let balanceTransactionId: String
    let presentmentAmount: Int; let presentmentCurrency: String; let settlementAmount: Int; let settlementCurrency: String
    let feeAmount: Int; let netAmount: Int; let feeBearer: UFitDistributionFeeBearer; let lines: [Line]; let createdAt: UFitTimestamp
    var hasDeficit: Bool { lines.contains { $0.netAmount < .zero } }
    func validate(reference: UFitPaymentSettlementDocument, brandID: String) throws {
        let invalid = UFitPaymentAllocationFailure.document
        guard paymentId == reference.payment.id, orderId == reference.payment.orderId, brandId == brandID,
              [paymentId, orderId, brandId, policyId].allSatisfy(UFitPaymentAllocationHTTP.validID), algorithm == UFitPaymentAllocationHTTP.algorithm,
              presentmentAmount == reference.payment.amount, presentmentCurrency == reference.payment.currency,
              presentmentAmount > .zero, settlementAmount > .zero, [presentmentAmount, settlementAmount, feeAmount].allSatisfy(UFitReturnContract.money),
              UFitReturnContract.currency(settlementCurrency), UFitPaymentAllocationHTTP.signedMoney(netAmount), settlementAmount - feeAmount == netAmount,
              chargeId.range(of: UFitPaymentSettlementHTTP.chargePattern, options: .regularExpression) != nil,
              balanceTransactionId.range(of: UFitPaymentSettlementHTTP.transactionPattern, options: .regularExpression) != nil,
              Set(lines.map(\.id)).count == lines.count,
              lines.filter({ $0.recipient.kind == .brand }).count == UFitReturnContract.single,
              lines.filter({ $0.recipient.kind == .platform }).count == UFitReturnContract.single else { throw invalid }
        if let receipt = reference.receipt {
            guard chargeId == receipt.chargeId, balanceTransactionId == receipt.balanceTransactionId,
                  settlementAmount == receipt.settlementAmount, settlementCurrency == receipt.settlementCurrency,
                  feeAmount == receipt.feeAmount, netAmount == receipt.netAmount else { throw invalid }
        }
        var commissionIDs = Set<String>()
        for line in lines {
            guard [line.presentmentAmount, line.grossAmount, line.feeAmount].allSatisfy(UFitReturnContract.money),
                  UFitPaymentAllocationHTTP.signedMoney(line.netAmount), line.grossAmount - line.feeAmount == line.netAmount,
                  line.feeAmount == (line.recipient.kind.rawValue == feeBearer.rawValue ? feeAmount : .zero) else { throw invalid }
            if line.recipient.kind == .brand, line.recipient.beneficiaryID != brandID { throw invalid }
            if let id = line.recipient.commissionID, !commissionIDs.insert(id).inserted { throw invalid }
        }
        guard UFitReturnContract.sum(lines.map(\.presentmentAmount)) == presentmentAmount,
              UFitReturnContract.sum(lines.map(\.grossAmount)) == settlementAmount,
              UFitReturnContract.sum(lines.map(\.feeAmount)) == feeAmount,
              UFitReturnContract.sum(lines.map(\.netAmount)) == netAmount else { throw invalid }
        try validateRounding()
    }
    private struct RoundingQuota { let key: String; let floor: Int; let remainder: Int }
    private func validateRounding() throws {
        let invalid = UFitPaymentAllocationFailure.document
        var quotas = [RoundingQuota]()
        for line in lines {
            // Both factors are bounded to signed 32-bit minor units; their product fits the 64-bit iOS Int.
            let product = line.presentmentAmount * settlementAmount
            quotas.append(.init(key: line.id, floor: product / presentmentAmount, remainder: product % presentmentAmount))
        }
        quotas.sort { left, right in left.remainder == right.remainder ? left.key < right.key : left.remainder > right.remainder }
        guard let sum = UFitReturnContract.sum(quotas.map { $0.floor }) else { throw invalid }
        let remaining = settlementAmount - sum
        guard remaining >= .zero, remaining < quotas.count else { throw invalid }
        for (index, quota) in quotas.enumerated() {
            let expected = quota.floor + (index < remaining ? UFitReturnContract.single : .zero)
            guard lines.first(where: { $0.id == quota.key })?.grossAmount == expected else { throw invalid }
        }
    }
}
