import Foundation

struct UFitPaymentDisbursementDocument: Decodable {
    enum State: String, Decodable { case notRequested = "not_requested", queued, processing, waiting, needsReview = "needs_review" }
    struct Allocation: Decodable {
        let state: UFitPaymentAllocationDocument.State
        @UFitRequiredNullable var blockReason: UFitPaymentAllocationDocument.BlockReason?
        let context: UFitPaymentAllocationDocument.Context
    }
    struct Operation: Decodable, Identifiable {
        enum Kind: String, Decodable { case transfer, reversal }
        enum State: String, Decodable { case open, recorded, superseded }
        enum Funding: String, Decodable { case charge, balance = "available_balance" }
        struct Receipt: Decodable { let id: String; let recordedAt: UFitTimestamp }
        let id: String; let kind: Kind; let state: State; let armed: Bool; let allocationKey: String
        @UFitRequiredNullable var originalOperationId: String?
        let amount: Int; let currency: String
        @UFitRequiredNullable var funding: Funding?
        let createdAt: UFitTimestamp
        @UFitRequiredNullable var receipt: Receipt?
    }
    let paymentId: String; let orderId: String; let asOf: UFitTimestamp; let allocation: Allocation; let state: State
    @UFitRequiredNullable var reason: UFitPaymentDisbursementReason?
    @UFitRequiredNullable var nextAttemptAt: UFitTimestamp?
    @UFitRequiredNullable var assessment: UFitPaymentDisbursementAssessment?
    @UFitRequiredNullable var assessmentRecordedAt: UFitTimestamp?
    let operations: [Operation]
    var transferred: Int { operations.filter { $0.kind == .transfer && $0.receipt != nil }.reduce(.zero) { $0 + $1.amount } }
    var recovered: Int { operations.filter { $0.kind == .reversal && $0.receipt != nil }.reduce(.zero) { $0 + $1.amount } }
    var netTransferred: Int { transferred - recovered }
    var targets: UFitPaymentDisbursementAssessment.Targets? { assessment?.targets }
    var hasDeficit: Bool {
        guard let assessment, case .settled(let targets, _) = assessment else { return false }
        return targets.lines.contains { $0.netAmount < .zero }
    }
    var awaitsConfirmation: Bool {
        guard state == .waiting, operations.contains(where: { $0.state == .open && $0.armed }) else { return false }
        return reason == .creationUnconfirmed || reason == .providerUnavailable || reason == .localUnavailable
    }
    var waitsForServer: Bool { state == .queued || state == .processing || awaitsConfirmation }
    func validate(reference: UFitPaymentSettlementDocument, brandID: String) throws {
        let invalid = UFitPaymentDisbursementFailure.document, context = allocation.context
        guard paymentId == reference.payment.id, orderId == reference.payment.orderId,
              [paymentId, orderId, brandID].allSatisfy(UFitPaymentAllocationHTTP.validID),
              context.brand.id == brandID, context.orderNumber == reference.payment.orderNumber,
              UFitReturnContract.nonempty(context.brand.name), context.liveMode == reference.receipt?.liveMode, context.liveMode != nil,
              (allocation.state == .blocked) == (allocation.blockReason != nil),
              (state == .queued || state == .waiting) == (nextAttemptAt != nil), state != .needsReview || reason != nil,
              (assessment != nil) == (assessmentRecordedAt != nil),
              Set(context.creatorItems.map(\.id)).count == context.creatorItems.count,
              Set(operations.map(\.id)).count == operations.count,
              Set(operations.compactMap { $0.receipt?.id }).count == operations.filter({ $0.receipt != nil }).count else { throw invalid }
        for item in context.creatorItems {
            guard [item.commissionId, item.creatorId].allSatisfy(UFitPaymentAllocationHTTP.validID),
                  UFitReturnContract.nonempty(item.creatorName), UFitReturnContract.nonempty(item.itemName) else { throw invalid }
        }
        if allocation.state != .recorded {
            guard assessment == nil, operations.isEmpty, context.creatorItems.isEmpty else { throw invalid }
        }
        try assessment?.validate(reference: reference, brandID: brandID, context: context)
        if let at = assessmentRecordedAt { guard at.value <= asOf.value else { throw invalid } }
        for operation in operations {
            guard UFitPaymentAllocationHTTP.validID(operation.id), operation.amount > .zero, UFitReturnContract.money(operation.amount),
                  UFitReturnContract.currency(operation.currency), operation.currency == reference.receipt?.settlementCurrency,
                  (operation.state == .recorded) == (operation.receipt != nil),
                  (operation.kind == .transfer) == (operation.funding != nil),
                  (operation.kind == .reversal) == (operation.originalOperationId != nil),
                  targets?.lines.contains(where: { $0.key == operation.allocationKey && $0.recipient.kind != .platform }) == true else { throw invalid }
            if let receipt = operation.receipt {
                let pattern = operation.kind == .transfer ? UFitPaymentDisbursementHTTP.transferPattern : UFitPaymentDisbursementHTTP.reversalPattern
                guard receipt.id.range(of: pattern, options: .regularExpression) != nil else { throw invalid }
            }
            if let id = operation.originalOperationId {
                guard UFitPaymentAllocationHTTP.validID(id), id != operation.id,
                      let original = operations.first(where: { $0.id == id }), original.kind == .transfer, original.state == .recorded,
                      original.allocationKey == operation.allocationKey, original.currency == operation.currency else { throw invalid }
            }
        }
        guard operations.filter({ $0.state == .open }).count <= UFitReturnContract.single,
              UFitReturnContract.sum(operations.filter({ $0.kind == .transfer && $0.receipt != nil }).map(\.amount)) != nil,
              UFitReturnContract.sum(operations.filter({ $0.kind == .reversal && $0.receipt != nil }).map(\.amount)) != nil else { throw invalid }
        for original in operations where original.kind == .transfer {
            let reversals = operations.filter { $0.kind == .reversal && $0.originalOperationId == original.id && $0.receipt != nil }
            guard let reversed = UFitReturnContract.sum(reversals.map(\.amount)), reversed <= original.amount else { throw invalid }
        }
    }
}

enum UFitPaymentDisbursementAssessment: Decodable {
    enum Phase: String, Decodable { case reserved = "return_reservation", settled, review = "needs_review" }
    private enum CodingKeys: String, CodingKey { case phase, reason, refundScanId, sourceGrossAmount, sourceFeeAmount, sourceNetAmount }
    struct Targets: Decodable {
        struct Line: Decodable, Identifiable {
            let key: String; let recipient: UFitPaymentAllocationRecipient
            let remainingPurchaseAmount: Int; let grossAmount: Int; let feeAmount: Int; let netAmount: Int
            var id: String { key }
        }
        let algorithm: String; let paymentId: String; let orderId: String; let brandId: String; let policyId: String
        let currency: String; let purchaseCurrency: String; let lines: [Line]
    }
    struct Source { let scanID: String; let gross: Int; let fee: Int; let net: Int }
    case reserved(Targets, UFitPaymentDisbursementReason), settled(Targets, Source), review(UFitPaymentDisbursementReason)
    var targets: Targets? { switch self { case .reserved(let targets, _), .settled(let targets, _): targets; case .review: nil } }
    var isReservation: Bool { if case .reserved = self { true } else { false } }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(Phase.self, forKey: .phase) {
        case .reserved: self = .reserved(try Targets(from: decoder), try values.decode(UFitPaymentDisbursementReason.self, forKey: .reason))
        case .settled:
            self = .settled(try Targets(from: decoder), .init(scanID: try values.decode(String.self, forKey: .refundScanId),
                gross: try values.decode(Int.self, forKey: .sourceGrossAmount), fee: try values.decode(Int.self, forKey: .sourceFeeAmount), net: try values.decode(Int.self, forKey: .sourceNetAmount)))
        case .review: self = .review(try values.decode(UFitPaymentDisbursementReason.self, forKey: .reason))
        }
    }
    func validate(reference: UFitPaymentSettlementDocument, brandID: String, context: UFitPaymentAllocationDocument.Context) throws {
        let invalid = UFitPaymentDisbursementFailure.document
        switch self {
        case .review(let reason):
            guard [.sourcesInvalid, .unmatchedRefunds, .missingRefundObservation].contains(reason) else { throw invalid }
        case .reserved(_, let reason): guard [.refundReadPending, .refundOutstanding].contains(reason) else { throw invalid }
        case .settled(let targets, let source):
            guard UFitPaymentAllocationHTTP.validID(source.scanID), [source.gross, source.fee, source.net].allSatisfy(UFitPaymentAllocationHTTP.signedMoney),
                  source.gross - source.fee == source.net,
                  UFitReturnContract.sum(targets.lines.map(\.grossAmount)) == source.gross,
                  UFitReturnContract.sum(targets.lines.map(\.feeAmount)) == source.fee,
                  UFitReturnContract.sum(targets.lines.map(\.netAmount)) == source.net else { throw invalid }
        }
        guard let targets else { return }
        guard targets.algorithm == UFitPaymentDisbursementHTTP.algorithm, targets.paymentId == reference.payment.id, targets.orderId == reference.payment.orderId,
              targets.brandId == brandID, UFitPaymentAllocationHTTP.validID(targets.policyId), targets.currency == reference.receipt?.settlementCurrency,
              targets.purchaseCurrency == reference.payment.currency, Set(targets.lines.map(\.key)).count == targets.lines.count,
              targets.lines.filter({ $0.recipient.kind == .brand }).count == UFitReturnContract.single,
              targets.lines.filter({ $0.recipient.kind == .platform }).count == UFitReturnContract.single,
              targets.lines.filter({ $0.recipient.kind == .creator }).count == context.creatorItems.count else { throw invalid }
        for line in targets.lines {
            guard line.key == line.recipient.key, UFitReturnContract.money(line.remainingPurchaseAmount),
                  [line.grossAmount, line.feeAmount, line.netAmount].allSatisfy(UFitPaymentAllocationHTTP.signedMoney), line.grossAmount - line.feeAmount == line.netAmount else { throw invalid }
            if line.recipient.kind == .brand { guard line.recipient.beneficiaryID == brandID else { throw invalid } }
            if line.recipient.kind == .creator {
                guard context.creatorItems.contains(where: { $0.commissionId == line.recipient.commissionID && $0.creatorId == line.recipient.beneficiaryID }) else { throw invalid }
            }
        }
    }
}
