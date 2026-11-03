import Foundation

extension UFitReturnSummaryDTO {
    var presentation: UFitReturnSummaryPresentation {
        .init(id: id, orderNumber: orderNumber, date: requestedAt.label, status: status, amount: UFitMoney.format(totalAmount, currency: currency), pieces: UFitOrderFormatting.pieceCount(itemCount))
    }
}
extension UFitReturnAmountsDTO {
    func presentation(currency: String) -> UFitReturnAmountsPresentation {
        .init(merchandise: UFitMoney.format(merchandiseAmount, currency: currency), shipping: UFitMoney.format(shippingAmount, currency: currency),
              taxes: UFitMoney.format(taxAmount, currency: currency), total: UFitMoney.format(totalAmount, currency: currency), policy: refundPolicyCode)
    }
}
extension UFitReturnDecisionDTO {
    var presentation: UFitReturnDecisionPresentation { .init(accepted: decision == .approved, date: at.label, reason: reason, instructions: instructions) }
}
extension UFitReturnItemDTO {
    func presentation(currency: String) -> UFitOrderPiece {
        .init(id: id, name: name, image: imageUrl, options: [size, color, String(localized: "Réf. \(sku)")].compactMap { $0 }.joined(separator: UFitOrderFormatting.separator),
              quantity: quantity, amount: UFitMoney.format(merchandiseAmount, currency: currency))
    }
}
extension UFitReturnDetailDTO {
    func presentation(stale: Bool) -> UFitReturnDetailPresentation {
        .init(summary: summary.presentation, items: items.map { $0.presentation(currency: currency) }, amounts: amounts.presentation(currency: currency),
              reason: reason, deadline: deadline.label, returnPolicy: returnPolicy, brandDecision: brandDecision?.presentation,
              disputeReason: dispute?.reason, disputeDate: dispute?.at.label, adminDecision: adminDecision?.presentation,
              tracking: tracking.map { .init(carrier: $0.carrier, trackingNumber: $0.trackingNumber, trackingURL: $0.trackingUrl.flatMap(UFitParcelTracking.url), sentDate: $0.sentAt.label) },
              receiptDate: reception?.at.label, restocked: Dictionary(uniqueKeysWithValues: items.compactMap { item in item.restockQuantity.map { (item.id, $0) } }),
              refundDate: refundedAt?.label, refundNote: refundNote,
              commands: stale ? [] : actions.map { .init(action: $0, expectedVersion: version) })
    }
    private var refundNote: String? {
        switch status {
        case .refundPending: String(localized: "La réception est enregistrée. Le prestataire doit encore confirmer le remboursement. Actualisez pour suivre son résultat.")
        case .refundFailed:
            refund?.providerStatus == .canceled
                ? String(localized: "Le remboursement a été annulé. La marque ou l’administration peut reprendre son traitement.")
                : String(localized: "Le remboursement sur le moyen de paiement d’origine n’est plus possible. Consultez son suivi pour la suite du traitement.")
        case .refunded:
            amounts.totalAmount == .zero ? String(localized: "Le retour est traité. Aucun montant n’était à rembourser.") : String(localized: "Le remboursement est confirmé par le prestataire. Son affichage sur votre compte dépend de votre banque.")
        default: nil
        }
    }
}
extension UFitReturnOptionsDTO {
    func presentation(orderNumber: String) -> UFitReturnOptionsPresentation {
        .init(orderNumber: orderNumber, items: items.map { item in
            .init(id: item.id, name: item.name, image: item.imageUrl,
                  options: [item.size, item.color, String(localized: "Réf. \(item.sku)")].compactMap { $0 }.joined(separator: UFitOrderFormatting.separator),
                  unitAmount: UFitMoney.format(item.unitPrice, currency: currency), availableQuantity: item.availableQuantity)
        }, returnPolicy: returnPolicy, refundPolicy: refundPolicyCode, deadline: deadline?.label, canRequest: canRequest,
              unavailableNote: unavailableReason?.label, openReturnID: openReturnId)
    }
}
