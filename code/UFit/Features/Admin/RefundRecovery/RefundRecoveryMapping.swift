import Foundation

extension UFitRefundRecoverySummaryDTO {
    var row: UFitRefundRecoveryRow {
        .init(reference: reference, orderNumber: orderNumber, context: kind.label + UFitRefundRecoveryCopy.separator + brandName,
            amount: UFitMoney.format(amount, currency: currency), failedAt: failedAt.label)
    }
}
extension UFitRefundRecoveryDetailDTO {
    var presentation: UFitRefundRecoveryDocument {
        .init(row: summary.row, explanation: summary.cause.explanation, providerReference: attempt.refundId, sourceTitle: summary.kind.sourceTitle)
    }
}
