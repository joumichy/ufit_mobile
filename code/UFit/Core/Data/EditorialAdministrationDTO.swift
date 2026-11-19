import Foundation

enum UFitEditorialStatus: String, Codable, CaseIterable {
    case draft, published, archived
    var title: String {
        switch self { case .draft: String(localized: "Brouillon"); case .published: String(localized: "Publiée"); case .archived: String(localized: "Archivée") }
    }
}
struct UFitManagedEditorial: Decodable, Identifiable {
    let id: String; let version: Int; let title: String; let description: String
    @UFitRequiredNullable var subtitle: String?
    @UFitRequiredNullable var coverImageUrl: String?
    let status: UFitEditorialStatus; let createdBy: String
    @UFitRequiredNullable var publishedAt: UFitTimestamp?
    let createdAt: UFitTimestamp; let updatedAt: UFitTimestamp
    func validate() throws {
        let l = UFitEditorialHTTP.self
        guard editorialUUID(id), editorialUUID(createdBy), (l.step...l.maximumVersion).contains(version),
              (l.titleMinimum...l.titleMaximum).contains(title.utf16.count), title == title.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, description.utf16.count <= l.descriptionMaximum,
              subtitle == nil || (!subtitle!.isEmpty && subtitle!.utf16.count <= l.subtitleMaximum),
              coverImageUrl == nil || editorialImageURL(coverImageUrl!),
              status != .published || publishedAt != nil, updatedAt.value >= createdAt.value,
              publishedAt == nil || (publishedAt!.value >= createdAt.value && publishedAt!.value <= updatedAt.value) else { throw UFitEditorialFailure.contract }
    }
}
struct UFitManagedEditorialItem: Decodable, Identifiable {
    let id: String; let collectionId: String; let itemType: UFitEditorialKind; let position: Int
    @UFitRequiredNullable var outfitId: String?
    @UFitRequiredNullable var productId: String?
    let title: String
    @UFitRequiredNullable var imageUrl: String?
    let available: Bool
    var reference: UFitEditorialReference {
        .init(kind: itemType, contentID: itemType == .outfit ? outfitId! : productId!, title: title, imageURL: imageUrl, available: available)
    }
    func validate(collectionID: String) throws {
        guard editorialUUID(id), collectionId == collectionID,
              (.zero..<UFitEditorialHTTP.maximumItems).contains(position), !title.isEmpty,
              imageUrl == nil || editorialImageURL(imageUrl!) else { throw UFitEditorialFailure.contract }
        switch itemType {
        case .outfit: guard let outfitId, editorialUUID(outfitId), productId == nil else { throw UFitEditorialFailure.contract }
        case .product: guard let productId, editorialUUID(productId), outfitId == nil else { throw UFitEditorialFailure.contract }
        }
    }
}
struct UFitManagedEditorialDetail: Decodable {
    let collection: UFitManagedEditorial; let items: [UFitManagedEditorialItem]
    func validate() throws {
        try collection.validate(); try items.forEach { try $0.validate(collectionID: collection.id) }
        guard items.count <= UFitEditorialHTTP.maximumItems, Set(items.map(\.id)).count == items.count,
              Set(items.map { $0.reference.id }).count == items.count,
              items.enumerated().allSatisfy({ $0.element.position == $0.offset }) else { throw UFitEditorialFailure.contract }
    }
    var draft: UFitEditorialDraft {
        .init(title: collection.title, subtitle: collection.subtitle ?? String(), description: collection.description,
              coverURL: collection.coverImageUrl ?? String(), references: items.map(\.reference))
    }
}
struct UFitManagedEditorialPage: Decodable {
    let items: [UFitManagedEditorial]
    @UFitRequiredNullable var nextCursor: String?
    func validate(cursor: String?, status: UFitEditorialStatus?) throws {
        try items.forEach { try $0.validate() }
        guard items.count <= UFitEditorialHTTP.pageSize, Set(items.map(\.id)).count == items.count,
              status == nil || items.allSatisfy({ $0.status == status }),
              nextCursor == nil || (editorialUUID(nextCursor!) && nextCursor == items.last?.id && nextCursor != cursor) else { throw UFitEditorialFailure.contract }
    }
}
struct UFitEditorialReceipt: Decodable {
    let requestId: String; let collectionId: String; let version: Int; let status: UFitEditorialStatus
    func validate(_ command: UFitEditorialCommand) throws {
        guard requestId == command.requestID, editorialUUID(collectionId),
              command.collectionID == nil || collectionId == command.collectionID,
              version == command.expectedVersion + UFitEditorialHTTP.step, status == command.kind.result else { throw UFitEditorialFailure.contract }
    }
}
struct UFitEditorialChange: Decodable {
    @UFitRequiredNullable var receipt: UFitEditorialReceipt?
    @UFitRequiredNullable var current: UFitManagedEditorialDetail?
    func validate(_ command: UFitEditorialCommand) throws {
        guard (receipt == nil) == (current == nil) else { throw UFitEditorialFailure.contract }
        if let receipt, let current {
            try receipt.validate(command); try current.validate()
            guard current.collection.id == receipt.collectionId, current.collection.version >= receipt.version,
                  current.collection.version != receipt.version || current.collection.status == receipt.status else { throw UFitEditorialFailure.contract }
        }
    }
}
