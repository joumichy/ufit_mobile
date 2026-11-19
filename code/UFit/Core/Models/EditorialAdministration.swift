import Foundation

struct UFitEditorialReference: Codable, Equatable, Identifiable {
    let kind: UFitEditorialKind; let contentID: String; let title: String; let imageURL: String?; let available: Bool
    var id: String { kind.rawValue + UFitEditorialAdminHTTP.separator + contentID }
}
struct UFitEditorialDraft: Codable, Equatable {
    var title = String(); var subtitle = String(); var description = String(); var coverURL = String()
    var references: [UFitEditorialReference] = []
    var fields: UFitEditorialFields {
        let sub = subtitle.trimmingCharacters(in: .whitespacesAndNewlines), cover = coverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return .init(title: title.trimmingCharacters(in: .whitespacesAndNewlines), subtitle: sub.isEmpty ? nil : sub,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines), coverImageUrl: cover.isEmpty ? nil : cover,
            items: references.enumerated().map { .init(itemType: $0.element.kind, contentID: $0.element.contentID, position: $0.offset) })
    }
    var errors: [UFitEditorialField: String] {
        let fields = fields; var result: [UFitEditorialField: String] = [:]
        if !(UFitEditorialHTTP.titleMinimum...UFitEditorialHTTP.titleMaximum).contains(fields.title.utf16.count) { result[.title] = UFitEditorialAdminCopy.titleError }
        if let subtitle = fields.subtitle, subtitle.utf16.count > UFitEditorialHTTP.subtitleMaximum { result[.subtitle] = UFitEditorialAdminCopy.subtitleError }
        if fields.description.isEmpty || fields.description.utf16.count > UFitEditorialHTTP.descriptionMaximum { result[.description] = UFitEditorialAdminCopy.descriptionError }
        if let cover = fields.coverImageUrl, !editorialImageURL(cover) || cover.utf16.count > UFitEditorialAdminHTTP.urlMaximum { result[.cover] = UFitEditorialAdminCopy.coverError }
        if references.count > UFitEditorialHTTP.maximumItems || Set(references.map(\.id)).count != references.count { result[.references] = UFitEditorialAdminCopy.referencesError }
        return result
    }
}
enum UFitEditorialField { case title, subtitle, description, cover, references }
struct UFitEditorialFields: Encodable {
    let title: String; let subtitle: String?; let description: String; let coverImageUrl: String?; let items: [Item]
    struct Item: Encodable {
        let itemType: UFitEditorialKind; let contentID: String; let position: Int
        private enum CodingKeys: String, CodingKey { case itemType, outfitId, productId, position }
        init(itemType: UFitEditorialKind, contentID: String, position: Int) { self.itemType = itemType; self.contentID = contentID; self.position = position }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(itemType, forKey: .itemType); try c.encode(position, forKey: .position)
            try c.encode(contentID, forKey: itemType == .outfit ? .outfitId : .productId)
        }
    }
    private enum CodingKeys: String, CodingKey { case title, subtitle, description, coverImageUrl, items }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title); try c.encode(subtitle, forKey: .subtitle); try c.encode(description, forKey: .description)
        try c.encode(coverImageUrl, forKey: .coverImageUrl); try c.encode(items, forKey: .items)
    }
    func validate() throws {
        let l = UFitEditorialHTTP.self
        guard (l.titleMinimum...l.titleMaximum).contains(title.utf16.count), title == title.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty, description.utf16.count <= l.descriptionMaximum, description == description.trimmingCharacters(in: .whitespacesAndNewlines),
              subtitle == nil || (!subtitle!.isEmpty && subtitle!.utf16.count <= l.subtitleMaximum && subtitle == subtitle!.trimmingCharacters(in: .whitespacesAndNewlines)),
              coverImageUrl == nil || (editorialImageURL(coverImageUrl!) && coverImageUrl!.utf16.count <= UFitEditorialAdminHTTP.urlMaximum),
              items.count <= l.maximumItems, items.enumerated().allSatisfy({ $0.offset == $0.element.position && editorialUUID($0.element.contentID) }),
              Set(items.map { $0.itemType.rawValue + UFitEditorialAdminHTTP.separator + $0.contentID }).count == items.count else { throw UFitEditorialFailure.contract }
    }
}
enum UFitEditorialCommandKind: String, Codable {
    case create, edit, publish, archive, restore
    var result: UFitEditorialStatus { switch self { case .create, .edit, .restore: .draft; case .publish: .published; case .archive: .archived } }
}
struct UFitEditorialCommand: Codable {
    let actorID: String; let requestID: String; let collectionID: String?
    let kind: UFitEditorialCommandKind; let expectedVersion: Int; let draft: UFitEditorialDraft?
    var fields: UFitEditorialFields? { draft?.fields }
    func validate(actorID: String) throws {
        guard self.actorID == actorID, editorialUUID(actorID), editorialUUID(requestID),
              (.zero..<UFitEditorialHTTP.maximumVersion).contains(expectedVersion) else { throw UFitEditorialFailure.contract }
        if kind == .create {
            guard collectionID == nil, expectedVersion == .zero, fields != nil else { throw UFitEditorialFailure.contract }
        } else {
            guard let collectionID, editorialUUID(collectionID), expectedVersion >= UFitEditorialHTTP.step,
                  (kind == .edit) == (fields != nil) else { throw UFitEditorialFailure.contract }
        }
        try fields?.validate()
    }
}
