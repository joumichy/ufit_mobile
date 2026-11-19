import Foundation

struct UFitReturnCreationDraft: Equatable {
    var reason = String()
    var quantities: [String: Int] = [:]
}
enum UFitReturnCreationField: Hashable { case reason, selection, quantity(String) }
struct UFitReturnActionDraft: Equatable {
    var reason = String()
    var instructions = String()
    var carrier = String()
    var trackingNumber = String()
    var trackingURL = String()
    var restockQuantities: [String: Int] = [:]
}
enum UFitReturnActionField: Hashable { case reason, instructions, carrier, trackingNumber, trackingURL, restock(String) }
enum UFitReturnInput {
    static let initialVersion = 1; static let versionStep = 1; static let maximumVersion = UFitDecimalInput.maximumInteger
    static let reasonMaximum = 2000; static let instructionsMaximum = 4000; static let maximumItems = 50
    static let fingerprintPattern = #"^[a-f0-9]{64}$"#
    static func errors(_ draft: UFitReturnCreationDraft, pieces: [UFitReturnSelectablePiece]) -> [UFitReturnCreationField: String] {
        var result: [UFitReturnCreationField: String] = [:]
        let ids = Set(pieces.map(\.id))
        if !UFitServerTextInput.valid(draft.reason, maximum: reasonMaximum) { result[.reason] = String(localized: "Indiquez le motif du retour, jusqu’à 2 000 caractères.") }
        if draft.quantities.contains(where: { !ids.contains($0.key) }) { result[.selection] = String(localized: "La sélection a changé. Actualisez avant de continuer.") }
        for piece in pieces {
            let value = draft.quantities[piece.id] ?? .zero
            if !(.zero...piece.availableQuantity).contains(value) { result[.quantity(piece.id)] = String(localized: "Choisissez une quantité parmi les pièces encore éligibles.") }
        }
        let selected = draft.quantities.values.filter { $0 > .zero }.count
        if selected == .zero || selected > maximumItems { result[.selection] = String(localized: "Sélectionnez au moins une pièce, jusqu’à 50 lignes par retour.") }
        return result
    }
    static func errors(_ draft: UFitReturnActionDraft, action: UFitReturnAction, pieces: [UFitOrderPiece]) -> [UFitReturnActionField: String] {
        var result: [UFitReturnActionField: String] = [:]
        if action.needsReason && !UFitServerTextInput.valid(draft.reason, maximum: reasonMaximum) { result[.reason] = String(localized: "Indiquez un motif, jusqu’à 2 000 caractères.") }
        if action.needsInstructions && !UFitServerTextInput.valid(draft.instructions, maximum: instructionsMaximum) { result[.instructions] = String(localized: "Précisez comment retourner les pièces, jusqu’à 4 000 caractères.") }
        if action.needsTracking {
            if !UFitServerTextInput.valid(draft.carrier, maximum: UFitParcelTracking.carrierMaximum) { result[.carrier] = String(localized: "Indiquez le transporteur, jusqu’à 120 caractères.") }
            if !UFitServerTextInput.valid(draft.trackingNumber, maximum: UFitParcelTracking.numberMaximum) { result[.trackingNumber] = String(localized: "Indiquez le numéro de suivi, jusqu’à 160 caractères.") }
            if !UFitServerTextInput.trimmed(draft.trackingURL).isEmpty && UFitParcelTracking.url(draft.trackingURL) == nil { result[.trackingURL] = String(localized: "Saisissez un lien HTTPS valide ou laissez ce champ vide.") }
        }
        if action == .receive {
            let ids = Set(pieces.map(\.id))
            for piece in pieces {
                guard let quantity = draft.restockQuantities[piece.id], (.zero...piece.quantity).contains(quantity) else {
                    result[.restock(piece.id)] = String(localized: "Choisissez combien de pièces reçues remettre en stock."); continue
                }
            }
            if draft.restockQuantities.keys.contains(where: { !ids.contains($0) }), let first = pieces.first { result[.restock(first.id)] = String(localized: "Les pièces du retour ont changé. Actualisez le dossier.") }
        }
        return result
    }
}
