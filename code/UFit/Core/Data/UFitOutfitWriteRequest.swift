import Foundation

struct UFitOutfitWriteRequest: Codable, Equatable {
    struct Piece: Codable, Equatable {
        let id: String?; let productId: String?; let externalLabel: String?; let itemType: UFitOutfitItemType
        let position: Int; let isRequired: Bool; let isShoppable: Bool; let stylingNote: String?
    }
    struct Photo: Codable, Equatable { let id: String?; let url: String; let position: Int }
    let creatorId: String?; let brandId: String?; let requestId: String?; let expectedVersion: Int?
    let title: String; let description: String; let genderTarget: UFitGenderTarget?; let tagIds: [String]
    let items: [Piece]; let images: [Photo]
    init(draft: UFitOutfitDraft, tags: [UFitOutfitTag], scope: UFitOutfitScope, requestID: UUID?, editing: UFitOutfitRevision?) throws {
        guard UUID(uuidString: scope.profileID) != nil, UFitOutfitDraftValidation.draft(draft, tags: tags).isEmpty,
              (requestID != nil && editing == nil) || (requestID == nil && editing != nil),
              editing == nil || (UUID(uuidString: editing!.id) != nil && editing!.version >= UFitOutfitInput.versionInitial),
              Set(draft.pieces.compactMap(\.serverID)).count == draft.pieces.compactMap(\.serverID).count,
              Set(draft.photos.compactMap(\.serverID)).count == draft.photos.compactMap(\.serverID).count else { throw UFitOutfitContractError.draft }
        creatorId = editing == nil && scope.kind == .creator ? scope.profileID : nil
        brandId = editing == nil && scope.kind == .brand ? scope.profileID : nil
        requestId = requestID?.uuidString; expectedVersion = editing?.version
        title = UFitOutfitInput.trimmed(draft.title); description = UFitOutfitInput.trimmed(draft.description)
        genderTarget = draft.gender; tagIds = draft.tagIDs.sorted()
        items = try draft.pieces.enumerated().map { position, piece in
            guard (piece.serverID == nil || editing != nil), piece.serverID == nil || UUID(uuidString: piece.serverID!) != nil,
                  piece.product == nil || UUID(uuidString: piece.product!.id) != nil else { throw UFitOutfitContractError.draft }
            let note = UFitOutfitInput.trimmed(piece.note)
            return .init(id: editing == nil ? nil : piece.serverID, productId: piece.product?.id,
                externalLabel: piece.isProduct ? nil : UFitOutfitInput.trimmed(piece.externalLabel), itemType: piece.type,
                position: position, isRequired: piece.isRequired, isShoppable: piece.isProduct, stylingNote: note.isEmpty ? nil : note)
        }
        images = try draft.photos.enumerated().map { position, photo in
            guard let url = photo.url, photo.transfer == .ready, let source = URL(string: url), let scheme = source.scheme,
                  UFitMultipartEncoding.allowedSchemes.contains(scheme), source.host != nil, source.user == nil, source.password == nil,
                  (photo.serverID == nil || editing != nil), photo.serverID == nil || UUID(uuidString: photo.serverID!) != nil else { throw UFitOutfitContractError.draft }
            return .init(id: editing == nil ? nil : photo.serverID, url: url, position: position)
        }
    }
    var creationScope: UFitOutfitScope? {
        if let creatorId, brandId == nil { return .init(profileID: creatorId, kind: .creator) }
        if let brandId, creatorId == nil { return .init(profileID: brandId, kind: .brand) }
        return nil
    }
}
