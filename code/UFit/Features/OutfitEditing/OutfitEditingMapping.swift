import Foundation

extension UFitManagedOutfit {
    func row() -> UFitManagedOutfitRow {
        .init(id: id, title: title, author: owner?.name, image: images.sorted { $0.position < $1.position }.first?.displayUrl, status: status, price: UFitMoney.ranges(prices))
    }
    func presentation() -> UFitManagedOutfitPresentation {
        .init(id: id, version: version, title: title, description: description, author: owner?.name, status: status, ownerStatus: owner?.status,
            rejectionReason: rejectionReason, price: UFitMoney.ranges(prices), photos: images.sorted { $0.position < $1.position }.map { .init(id: $0.id, source: $0.displayUrl) },
            pieces: items.sorted { $0.position < $1.position }.map { item in
                .init(id: item.id, title: item.label, type: item.itemType, image: item.product?.imageUrl,
                    price: item.product.map { UFitMoney.format($0.price, currency: $0.currency) }, isRequired: item.isRequired,
                    isShoppable: item.isShoppable, isAvailable: !item.isShoppable || item.product != nil, note: item.stylingNote)
            }, tags: tags, gender: genderTarget, submissionIssue: submissionIssue)
    }
    func draft() -> UFitOutfitDraft {
        var value = UFitOutfitDraft()
        value.title = title; value.description = description; value.gender = genderTarget; value.tagIDs = Set(tags.map(\.id))
        value.pieces = items.sorted { $0.position < $1.position }.map { item in
            var piece = UFitOutfitPieceDraft()
            piece.serverID = item.id; piece.type = item.itemType; piece.isRequired = item.isRequired; piece.note = item.stylingNote ?? String()
            if let id = item.productId {
                piece.product = .init(id: id, name: item.label, brandName: nil, image: item.product?.imageUrl,
                    price: item.product.map { UFitMoney.format($0.price, currency: $0.currency) })
            }
            piece.externalLabel = item.externalLabel ?? String()
            return piece
        }
        value.photos = images.sorted { $0.position < $1.position }.map { .init(id: UUID(), serverID: $0.id, source: $0.displayUrl, url: $0.url, transfer: .ready) }
        return value
    }
    private var submissionIssue: String? {
        if owner?.status != .active || author == nil { return Copy.profile }
        if UFitOutfitInput.trimmed(description).isEmpty { return Copy.description }
        if images.isEmpty { return Copy.photo }
        if items.isEmpty { return Copy.piece }
        if items.contains(where: { $0.isShoppable && $0.product == nil }) { return Copy.unavailable }
        return nil
    }
    private enum Copy {
        static let profile = String(localized: "Activez le profil avant l’envoi à validation.")
        static let description = String(localized: "Décrivez la tenue avant l’envoi à validation.")
        static let photo = String(localized: "Ajoutez une photo avant l’envoi à validation.")
        static let piece = String(localized: "Ajoutez une pièce avant l’envoi à validation.")
        static let unavailable = String(localized: "Remplacez les produits indisponibles avant l’envoi à validation.")
    }
}
