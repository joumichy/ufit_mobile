import Foundation

extension UFitManagedOutfit {
    func row() -> UFitManagedOutfitRow {
        .init(id: id, title: title, author: owner?.name, image: images.sorted { $0.position < $1.position }.first?.displayUrl, status: status, price: UFitMoney.ranges(prices))
    }
    func presentation() -> UFitManagedOutfitPresentation {
        .init(id: id, version: version, title: title, description: description, author: owner?.name, status: status, ownerStatus: owner?.status,
            price: UFitMoney.ranges(prices), photos: images.sorted { $0.position < $1.position }.map { image in
                .init(id: image.id, source: image.displayUrl, pins: pins.filter { $0.imageId == image.id }.compactMap { pin in
                    guard let item = items.first(where: { $0.id == pin.itemId }) else { return nil }
                    return .init(id: item.id, label: item.label, itemType: item.itemType, x: pin.x, y: pin.y)
                })
            },
            pieces: items.sorted { $0.position < $1.position }.map { item in
                .init(id: item.id, title: item.label, type: item.itemType, image: item.product?.imageUrl,
                    price: item.product.map { UFitMoney.format($0.price, currency: $0.currency) }, isRequired: item.isRequired,
                    isShoppable: item.isShoppable, isAvailable: !item.isShoppable || item.product != nil, note: item.stylingNote)
            }, tags: tags, gender: genderTarget, publicationIssue: publicationIssue,
            scheduledFor: scheduledFor.flatMap(UFitPublicationDate.parse), publicationTimeZone: publicationTimeZone)
    }
    func draft() -> UFitOutfitDraft {
        var value = UFitOutfitDraft()
        value.title = title; value.description = description; value.gender = genderTarget; value.tagIDs = Set(tags.map(\.id))
        value.pieces = items.sorted { $0.position < $1.position }.map { item in
            var piece = UFitOutfitPieceDraft(type: item.itemType)
            piece.serverID = item.id; piece.isRequired = item.isRequired; piece.note = item.stylingNote ?? String()
            if let id = item.productId {
                piece.product = .init(id: id, name: item.label, brandName: item.product?.brandName, image: item.product?.imageUrl,
                    price: item.product.map { UFitMoney.format($0.price, currency: $0.currency) })
            }
            piece.externalLabel = item.externalLabel ?? String()
            return piece
        }
        value.photos = images.sorted { $0.position < $1.position }.map { image in
            .init(id: UUID(), serverID: image.id, source: image.displayUrl, url: image.url, transfer: .ready,
                pins: pins.filter { $0.imageId == image.id }.compactMap { pin in
                    guard let piece = value.pieces.first(where: { $0.serverID == pin.itemId }) else { return nil }
                    return .init(pieceID: piece.id, x: pin.x, y: pin.y)
                })
        }
        return value
    }
    private var publicationIssue: String? {
        if owner?.status != .active || author == nil { return Copy.profile }
        if UFitOutfitInput.trimmed(description).isEmpty { return Copy.description }
        if images.isEmpty { return Copy.photo }
        if items.isEmpty { return Copy.piece }
        if items.contains(where: { $0.isShoppable && $0.product == nil }) { return Copy.unavailable }
        return nil
    }
    private enum Copy {
        static let profile = String(localized: "Activez le profil avant de publier.")
        static let description = String(localized: "Décrivez la tenue avant de publier.")
        static let photo = String(localized: "Ajoutez une photo avant de publier.")
        static let piece = String(localized: "Ajoutez une pièce avant de publier.")
        static let unavailable = String(localized: "Remplacez les produits indisponibles avant de publier.")
    }
}
