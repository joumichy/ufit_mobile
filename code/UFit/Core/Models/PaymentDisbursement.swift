import Foundation

enum UFitPaymentDisbursementReason: String, Decodable {
    case instructionInvalid = "transfer_instruction_invalid", providerUnavailable = "transfer_provider_unavailable", providerMismatch = "transfer_provider_mismatch"
    case modeMismatch = "transfer_mode_mismatch", accountIncomplete = "transfer_account_incomplete", captureChanged = "transfer_capture_changed"
    case refundOpen = "transfer_refund_open", disputed = "transfer_disputed", reversalExceedsRemaining = "transfer_reversal_exceeds_remaining"
    case localUnavailable = "transfer_local_state_unavailable", awaitingDelivery = "transfer_awaiting_delivery", returnWindow = "transfer_return_window"
    case returnOpen = "transfer_return_open", cancellationOpen = "transfer_cancellation_open", inactiveProfile = "transfer_profile_inactive"
    case adjustmentPending = "transfer_adjustment_pending", instructionSuperseded = "transfer_instruction_superseded"
    case executionNotArmed = "transfer_execution_not_armed", creationUnconfirmed = "transfer_creation_unconfirmed"
    case sourcesInvalid = "disbursement_sources_invalid", unmatchedRefunds = "disbursement_refunds_unmatched"
    case missingRefundObservation = "disbursement_refund_observation_missing", refundReadPending = "disbursement_refund_read_pending"
    case refundOutstanding = "disbursement_refund_outstanding", ledgerInvalid = "disbursement_ledger_invalid"
    case allocationUnavailable = "disbursement_allocation_unavailable", executionUnavailable = "disbursement_execution_unavailable", current = "disbursement_current"
    var title: String {
        switch self {
        case .accountIncomplete: String(localized: "Compte Stripe à compléter")
        case .awaitingDelivery: String(localized: "Livraison attendue")
        case .returnWindow: String(localized: "Délai de retour en cours")
        case .returnOpen: String(localized: "Retour à traiter")
        case .cancellationOpen: String(localized: "Annulation à rapprocher")
        case .inactiveProfile: String(localized: "Profil à vérifier")
        case .creationUnconfirmed: String(localized: "Confirmation attendue")
        case .refundOutstanding, .refundReadPending, .refundOpen, .adjustmentPending: String(localized: "Remboursement à rapprocher")
        case .providerUnavailable, .executionUnavailable, .localUnavailable: String(localized: "Vérification indisponible")
        case .current: String(localized: "Versements à jour")
        case .executionNotArmed: UFitPaymentDisbursementCopy.processing
        default: String(localized: "Vérification nécessaire")
        }
    }
    var message: String {
        switch self {
        case .accountIncomplete: String(localized: "Un bénéficiaire doit terminer la configuration de son compte Stripe avant de recevoir un versement.")
        case .awaitingDelivery: String(localized: "Les commissions créateur attendent la livraison, puis le délai de retour défini à l’achat.")
        case .returnWindow: String(localized: "Les commissions seront traitées après la fin du délai de retour, si aucun retour ne reste ouvert.")
        case .returnOpen: String(localized: "Le retour doit être traité avant de poursuivre les versements concernés.")
        case .cancellationOpen: String(localized: "Le résultat de l’annulation et du remboursement doit être confirmé.")
        case .inactiveProfile: String(localized: "Un profil bénéficiaire n’est pas actif. Son accès doit être rétabli avant un nouvel envoi.")
        case .creationUnconfirmed: String(localized: "Une opération est encore vérifiée auprès de Stripe. Aucun nouvel envoi ne la remplace pendant cette vérification.")
        case .refundOutstanding, .refundReadPending, .refundOpen: String(localized: "Le remboursement et ses montants Stripe doivent être confirmés avant un nouveau versement.")
        case .adjustmentPending: String(localized: "Les montants après retour doivent être rapprochés avant de poursuivre les versements.")
        case .providerUnavailable, .executionUnavailable, .localUnavailable: String(localized: "Le traitement reprendra après vérification du service. Vous pouvez relancer cette vérification.")
        case .current: String(localized: "Les opérations connues sont enregistrées.")
        case .disputed: String(localized: "Un litige Stripe doit être résolu avant un nouvel envoi.")
        case .allocationUnavailable: String(localized: "Les conditions de l’achat et sa répartition doivent être disponibles pour calculer les versements.")
        case .unmatchedRefunds, .missingRefundObservation: String(localized: "Les remboursements Stripe et ceux de la commande ne concordent pas encore. Vérifiez leur rapprochement.")
        case .executionNotArmed: UFitPaymentDisbursementCopy.processingScope
        default: String(localized: "Les informations financières doivent être rapprochées avant de poursuivre. Aucun nouvel envoi n’est autorisé tant que cette vérification reste ouverte.")
        }
    }
    var allowsResume: Bool {
        switch self {
        case .accountIncomplete, .inactiveProfile, .providerUnavailable, .executionUnavailable, .localUnavailable,
             .allocationUnavailable, .sourcesInvalid, .unmatchedRefunds, .missingRefundObservation, .ledgerInvalid,
             .providerMismatch, .captureChanged, .modeMismatch, .instructionInvalid, .reversalExceedsRemaining, .instructionSuperseded: true
        default: false
        }
    }
}
enum UFitPaymentDisbursementCopy {
    static let title = String(localized: "Versements"), icon = "arrow.left.arrow.right"
    static let loading = String(localized: "Lecture des versements"), processing = String(localized: "Traitement en cours")
    static let processingScope = String(localized: "Les versements admissibles sont traités automatiquement. Vous pouvez quitter cet écran pendant le traitement.")
    static let notRequested = String(localized: "Versements à vérifier"), notRequestedScope = String(localized: "La vérification calcule les montants admissibles et reprend leur traitement automatique.")
    static let verify = String(localized: "Vérifier les versements"), resume = String(localized: "Relancer la vérification")
    static let check = String(localized: "Actualiser le suivi"), noOperations = String(localized: "Aucune opération enregistrée")
    static let noOperationsScope = String(localized: "Les transferts et leurs récupérations apparaîtront ici lorsqu’ils seront enregistrés.")
    static let net = String(localized: "Net transféré"), transferScope = String(localized: "Vers les comptes Stripe des bénéficiaires. Les virements bancaires ne sont pas suivis ici.")
    static let transferred = String(localized: "Transféré"), recovered = String(localized: "Récupéré"), history = String(localized: "Opérations")
    static let targets = String(localized: "Parts calculées"), targetsScope = String(localized: "Montants attribués, distincts des transferts enregistrés.")
    static let reservation = String(localized: "Parts réservées pendant le retour"), reservationScope = String(localized: "Ces plafonds protègent le remboursement en cours. Ils ne représentent pas un solde disponible.")
    static let deficit = String(localized: "Solde à régulariser"), deficitScope = String(localized: "Une part reste négative après frais ou remboursement. Ce déficit doit être traité avant tout nouveau versement.")
    static let transfer = String(localized: "Transfert"), reversal = String(localized: "Récupération de transfert")
    static let waiting = String(localized: "En attente de confirmation"), recorded = String(localized: "Enregistrée chez Stripe"), retired = String(localized: "Instruction retirée")
    static let details = String(localized: "Détails des opérations"), receipt = String(localized: "Référence Stripe"), instruction = String(localized: "Référence de suivi")
    static let latestCalculation = String(localized: "Dernier calcul"), initial = String(localized: "Voir la répartition initiale")
    static let purchase = String(localized: "Achat d’origine"), gross = String(localized: "Part brute"), fee = String(localized: "Frais attribués")
    static let loadFailed = String(localized: "Le suivi des versements n’a pas pu être actualisé. Réessayez.")
    static let invalid = String(localized: "Les informations reçues sont incohérentes. Actualisez le suivi avant de continuer.")
    static let missing = String(localized: "Ce paiement n’est plus disponible. Revenez à la commande et actualisez.")
    static let unconfirmed = String(localized: "Le traitement n’a pas pu être confirmé. Actualisez le suivi avant de continuer.")
    static let preparing = String(localized: "En préparation"), prepared = String(localized: "Préparée le"), recordedAt = String(localized: "Enregistrée le")
    static let previous = String(localized: "Dernières données consultées")
    static let locale = Locale(identifier: "fr_CH")
    static func date(_ timestamp: UFitTimestamp) -> String { timestamp.value.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(locale)) }
}
