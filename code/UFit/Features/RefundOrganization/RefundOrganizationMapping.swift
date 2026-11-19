import Foundation

extension UFitRefundOrganizationDocumentDTO {
    func presentation(scope: UFitRefundOrganizationScope) -> UFitRefundOrganizationPresentation {
        let title: String
        if let proof {switch proof.status {case .submitted: title = scope == .administrator ? UFitRefundProofCopy.review : UFitRefundProofCopy.accepted; case .rejected: title = UFitRefundReviewCopy.rejected; case .verified: title = UFitRefundReviewCopy.verified}}
        else {switch organization?.status {
        case .awaitingCustomer: title = scope == .customer ? UFitRefundOrganizationCopy.awaitingYourDetails : UFitRefundOrganizationCopy.awaitingCustomer
        case .ready: title = scope == .customer ? UFitRefundOrganizationCopy.sentDetails : UFitRefundOrganizationCopy.ready
        case nil: title = UFitRefundRecoveryCopy.pending
        }}
        let action = actions.first
        let actionTitle: String?
        switch action {
        case .arrange: actionTitle = organization == nil ? UFitRefundOrganizationCopy.arrange : UFitRefundOrganizationCopy.editInstructions
        case .provideDetails: actionTitle = organization?.customerDetails == nil ? UFitRefundOrganizationCopy.reply : UFitRefundOrganizationCopy.editReply
        case nil: actionTitle = nil
        }
        return .init(reference: summary.orderNumber, context: summary.row.context, amount: UFitMoney.format(summary.amount, currency: summary.currency), status: title,
            method: organization?.methodLabel, instructions: organization?.instructions, details: organization?.customerDetails, updatedAt: organization?.updatedAt.label, proof: proof?.presentation, action: action, actionTitle: actionTitle)
    }
}
extension UFitRefundProofDTO {
    var presentation: UFitRefundProofPresentation {
        let statusTitle: String
        switch status {case .submitted: statusTitle = UFitRefundProofCopy.review; case .rejected: statusTitle = UFitRefundReviewCopy.rejected; case .verified: statusTitle = UFitRefundReviewCopy.verified}
        return .init(reference: transferReference, date: UFitTimestamp(value: transferredOnDate).label, status: statusTitle, decisionReason: review?.reason, verificationReference: review?.verificationReference, reviewedAt: review?.reviewedAt.label)
    }
}
