import Foundation

enum UFitRefundProofStatus: String, Decodable {case submitted, rejected, verified}
enum UFitRefundProofDecision: String, Codable {case reject, confirm}
enum UFitRefundReviewCopy {
    static let title = String(localized: "Vérifier le remboursement")
    static let resume = String(localized: "Vérifier la décision envoyée")
    static let reject = String(localized: "Refuser le justificatif")
    static let confirm = String(localized: "Confirmer le règlement vérifié")
    static let reason = String(localized: "Motif de la décision")
    static let decision = String(localized: "Décision")
    static let submit = String(localized: "Enregistrer la décision")
    static let verification = String(localized: "Référence de vérification du règlement")
    static let rejected = String(localized: "Justificatif refusé")
    static let verified = String(localized: "Remboursement confirmé par Ufit")
    static let reviewedAt = String(localized: "Décision du")
    static let confirmation = String(localized: "Confirmer ce remboursement ?")
    static let consequence = String(localized: "Confirmez uniquement après vérification du règlement effectif. Cette décision solde le remboursement et ajuste les commissions ; elle ne déclenche aucun virement.")
    static let localFailure = String(localized: "La décision locale ne peut pas être relue. Vérifiez le dossier avant une nouvelle saisie.")
    static let noLongerReviewable = String(localized: "Cette pièce ne peut plus être examinée. Votre saisie est conservée.")
    static let recorded = String(localized: "La décision a été enregistrée.")
    static let notRecorded = String(localized: "Cette décision n’est pas enregistrée. Vous pouvez renvoyer la même demande.")
    static let settlement = String(localized: "Règlement externe vérifié")
    static func proofNumber(_ sequence: Int) -> String {String(localized: "Justificatif n° \(sequence)")}
    static func settled(_ amount: String) -> String {String(localized: "Le remboursement de \(amount) a été vérifié par Ufit sur le moyen convenu.")}
}
enum UFitRefundReviewRules {static let reasonMaximum = 2000, referenceMaximum = 160, missingReceipt = "refund_proof_review_receipt_missing", root = "/proof-reviews"}
struct UFitRefundProofReviewRequest: Codable {
    let requestId: String
    let expectedVersion: Int
    let proofId: String
    let decision: UFitRefundProofDecision
    let reason: String
    let verificationReference: String?
    func validate() throws {
        guard UUID(uuidString: requestId) != nil, UUID(uuidString: proofId) != nil,
              (UFitRefundOrganizationRules.firstVersion...UFitRefundOrganizationRules.maximumVersion).contains(expectedVersion),
              UFitServerTextInput.valid(reason, maximum: UFitRefundReviewRules.reasonMaximum) else {throw UFitRefundOrganizationFailure.localRecord}
        switch decision {
        case .reject: guard verificationReference == nil else {throw UFitRefundOrganizationFailure.localRecord}
        case .confirm: guard let verificationReference, UFitServerTextInput.valid(verificationReference, maximum: UFitRefundReviewRules.referenceMaximum) else {throw UFitRefundOrganizationFailure.localRecord}
        }
    }
}
