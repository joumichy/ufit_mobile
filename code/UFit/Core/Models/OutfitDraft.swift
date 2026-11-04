import Foundation

enum UFitOutfitInput {
    static let titleMin = 2; static let titleMax = 120; static let descriptionMax = 6000
    static let labelMin = 1; static let labelMax = 200; static let noteMax = 2000
    static let itemsMax = 24; static let photosMax = 12; static let tagsMax = 24
    static let versionInitial = 1; static let positionStep = 1
    static func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func textValid(_ value: String, minimum: Int, maximum: Int) -> Bool { (minimum...maximum).contains(trimmed(value).unicodeScalars.count) }
}
struct UFitOutfitProductChoice: Codable, Equatable, Identifiable {
    let id: String; let name: String; let brandName: String?; let image: String?; let price: String?
}
struct UFitOutfitPieceDraft: Codable, Equatable, Identifiable {
    var id = UUID()
    var serverID: String?
    var product: UFitOutfitProductChoice?
    var externalLabel = String()
    var type: UFitOutfitItemType
    var isRequired = true
    var note = String()
    var isProduct: Bool { product != nil }
    var title: String { product?.name ?? externalLabel }
}
struct UFitOutfitPhotoDraft: Codable, Equatable, Identifiable {
    let id: UUID
    let serverID: String?
    var source: String?
    var url: String?
    var transfer: UFitPhotoTransfer
    var previewData: Data?
    var pins: [UFitOutfitDraftPin] = []
    var canRetryUpload: Bool { if case .failed = transfer { url == nil } else { false } }
}
struct UFitOutfitDraft: Codable, Equatable {
    var title = String(); var description = String(); var gender: UFitGenderTarget?
    var tagIDs: Set<String> = []
    var pieces: [UFitOutfitPieceDraft] = []
    var photos: [UFitOutfitPhotoDraft] = []
}
enum UFitOutfitField: Hashable { case title, description, tags, pieces, photos }
enum UFitOutfitPieceField: Hashable { case label, note }
enum UFitOutfitDraftValidation {
    private enum Copy {
        static let title = String(localized: "Choisissez un titre de 2 à 120 caractères.")
        static let description = String(localized: "La description peut contenir au plus 6 000 caractères.")
        static let tags = String(localized: "Rechargez les styles et sélectionnez au plus 24 tags disponibles.")
        static let pieces = String(localized: "Vérifiez les pièces : au plus 24, avec chaque produit une seule fois.")
        static let photos = String(localized: "Vérifiez les photos : au plus 12, avec chaque envoi terminé.")
        static let label = String(localized: "Nommez cette pièce en 1 à 200 caractères.")
        static let note = String(localized: "La note de style peut contenir au plus 2 000 caractères.")
    }
    static func piece(_ piece: UFitOutfitPieceDraft) -> [UFitOutfitPieceField: String] {
        var errors: [UFitOutfitPieceField: String] = [:]
        if !piece.isProduct && !UFitOutfitInput.textValid(piece.externalLabel, minimum: UFitOutfitInput.labelMin, maximum: UFitOutfitInput.labelMax) { errors[.label] = Copy.label }
        if !UFitOutfitInput.textValid(piece.note, minimum: .zero, maximum: UFitOutfitInput.noteMax) { errors[.note] = Copy.note }
        return errors
    }
    static func draft(_ draft: UFitOutfitDraft, tags: [UFitOutfitTag]) -> [UFitOutfitField: String] {
        var errors: [UFitOutfitField: String] = [:]
        if !UFitOutfitInput.textValid(draft.title, minimum: UFitOutfitInput.titleMin, maximum: UFitOutfitInput.titleMax) { errors[.title] = Copy.title }
        if !UFitOutfitInput.textValid(draft.description, minimum: .zero, maximum: UFitOutfitInput.descriptionMax) { errors[.description] = Copy.description }
        if draft.tagIDs.count > UFitOutfitInput.tagsMax || !draft.tagIDs.isSubset(of: Set(tags.map(\.id))) { errors[.tags] = Copy.tags }
        let products = draft.pieces.compactMap { $0.product?.id }
        if draft.pieces.count > UFitOutfitInput.itemsMax || Set(products).count != products.count || draft.pieces.contains(where: { !piece($0).isEmpty }) { errors[.pieces] = Copy.pieces }
        if draft.photos.count > UFitOutfitInput.photosMax || draft.photos.contains(where: { photo in
            photo.transfer != .ready || photo.url == nil || Set(photo.pins.map(\.pieceID)).count != photo.pins.count || photo.pins.contains { pin in
                !draft.pieces.contains { $0.id == pin.pieceID } || !(.zero...UFitOutfitPin.coordinateMax).contains(pin.x) || !(.zero...UFitOutfitPin.coordinateMax).contains(pin.y)
            }
        }) { errors[.photos] = Copy.photos }
        return errors
    }
}
