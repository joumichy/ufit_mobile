import Foundation

struct UFitOutfitPin: Codable, Equatable {
    let imageId: String
    let itemId: String
    let x: Int
    let y: Int
    static let coordinateMax = 10000
    static func valid(_ pins: [Self], imageIDs: Set<String>, itemIDs: Set<String>) -> Bool {
        let pairs = pins.map { [$0.imageId, $0.itemId] }
        return pins.count <= UFitOutfitInput.photosMax * UFitOutfitInput.itemsMax && Set(pairs).count == pairs.count &&
            pins.allSatisfy { imageIDs.contains($0.imageId) && itemIDs.contains($0.itemId) &&
                (.zero...coordinateMax).contains($0.x) && (.zero...coordinateMax).contains($0.y) }
    }
}
struct UFitOutfitDraftPin: Codable, Equatable, Identifiable {
    let pieceID: UUID
    var x: Int
    var y: Int
    var id: UUID { pieceID }
}

struct UFitPhotoPinPresentation: Identifiable {
    let id: String; let label: String; let itemType: UFitOutfitItemType; let x: Int; let y: Int
}
