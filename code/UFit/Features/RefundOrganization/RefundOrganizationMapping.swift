import Foundation

extension UFitRefundOrganizationDocumentDTO {
    func presentation(scope: UFitRefundOrganizationScope) -> UFitRefundOrganizationPresentation {
        let title: String
        if proof != nil {title = scope == .administrator ? UFitRefundProofCopy.review : UFitRefundProofCopy.accepted}
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
            method: organization?.methodLabel, instructions: organization?.instructions, details: organization?.customerDetails, updatedAt: organization?.updatedAt.label, proof: proof.map {.init(reference: $0.transferReference, date: UFitTimestamp(value: $0.transferredOnDate).label)}, action: action, actionTitle: actionTitle)
    }
}
