import Foundation

enum UFitProfileImageHTTP {
    static let upload = "media/profile-uploads"
    static let selection = "media/profile-images/"
    static let assetPrefix = "/media/profile-assets/"
    static let imageSuffix = "/image"
    static let separator = "/"
    static let kind = "kind"; static let owner = "ownerId"; static let request = "requestId"
    static let get = "GET"; static let put = "PUT"; static let post = "POST"
    static let conflict = 409; static let tooLarge = 413; static let serverFailure = 500
    static let badRequest = 400; static let unauthorized = 401; static let forbidden = 403; static let missing = 404
    static let definitiveRejections: Set<Int> = [badRequest, unauthorized, forbidden, missing, conflict, tooLarge]
    static let versionChanged = "profile_image_version_changed"
    static let initialVersion = 0; static let versionStep = 1; static let maximumVersion = 2_147_483_647
}
struct UFitProfileImageScope: Hashable {
    enum Kind: String, Decodable { case account, creator, brand }
    let kind: Kind
    let ownerID: UUID
    var path: String { UFitProfileImageHTTP.selection + kind.rawValue + UFitProfileImageHTTP.separator + ownerID.uuidString.lowercased() }
}
struct UFitProfileImage: Decodable {
    let id: UUID?
    let url: String
    let displayUrl: String
    enum CodingKeys: String, CodingKey { case id, url, displayUrl }
    init(id: UUID, url: String, displayUrl: String) { self.id = id; self.url = url; self.displayUrl = displayUrl }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard values.contains(.id) else { throw UFitPhotoError.invalidResponse }
        id = try values.decodeIfPresent(UUID.self, forKey: .id)
        url = try values.decode(String.self, forKey: .url); displayUrl = try values.decode(String.self, forKey: .displayUrl)
    }
    func validate() throws {
        for raw in [url, displayUrl] {
            guard let value = URL(string: raw), let scheme = value.scheme, UFitMultipartEncoding.allowedSchemes.contains(scheme),
                  value.host != nil, value.user == nil, value.password == nil else { throw UFitPhotoError.invalidResponse }
        }
        if let id {
            guard let value = URLComponents(string: url), value.query == nil, value.fragment == nil,
                  value.path == UFitProfileImageHTTP.assetPrefix + id.uuidString.lowercased() + UFitProfileImageHTTP.imageSuffix else { throw UFitPhotoError.invalidResponse }
        }
    }
}
struct UFitProfileImageDocument: Decodable {
    let kind: UFitProfileImageScope.Kind
    let ownerId: UUID
    let version: Int
    @UFitRequiredNullable var image: UFitProfileImage?
    func validate(scope: UFitProfileImageScope) throws {
        guard kind == scope.kind, ownerId == scope.ownerID,
              (UFitProfileImageHTTP.initialVersion...UFitProfileImageHTTP.maximumVersion).contains(version) else { throw UFitPhotoError.invalidResponse }
        try image?.validate()
    }
}
struct UFitProfileImageCommand: Encodable {
    let requestId: UUID
    let expectedVersion: Int
    let assetId: UUID?
    enum CodingKeys: String, CodingKey { case requestId, expectedVersion, assetId }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(requestId, forKey: .requestId); try values.encode(expectedVersion, forKey: .expectedVersion)
        if let assetId { try values.encode(assetId, forKey: .assetId) } else { try values.encodeNil(forKey: .assetId) }
    }
}
struct UFitProfileImageReceipt: Decodable { let requestId: UUID; let version: Int }
private struct UFitUploadedProfileImage: Decodable {
    let kind: UFitProfileImageScope.Kind; let ownerId: UUID; let id: UUID; let url: String; let displayUrl: String
}
extension UFitAPIClient {
    func fetchProfileImage(scope: UFitProfileImageScope) async throws -> UFitProfileImageDocument {
        do {
            let result: UFitProfileImageDocument = try await send(UFitProfileImageHTTP.get, path: scope.path, requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
            try result.validate(scope: scope); return result
        } catch is DecodingError { throw UFitPhotoError.invalidResponse }
    }
    func uploadProfileImage(scope: UFitProfileImageScope, requestID: UUID, jpeg: Data) async throws -> UFitProfileImage {
        guard !jpeg.isEmpty else { throw UFitPhotoError.invalidImage }
        guard jpeg.count <= UFitImageUploadContract.maximumBytes else { throw UFitPhotoError.tooLarge }
        let body = UFitMultipartEncoding.image(fields: [(UFitProfileImageHTTP.kind, scope.kind.rawValue),
            (UFitProfileImageHTTP.owner, scope.ownerID.uuidString), (UFitProfileImageHTTP.request, requestID.uuidString)], jpeg: jpeg)
        do {
            let result: UFitUploadedProfileImage = try await send(UFitProfileImageHTTP.post, path: UFitProfileImageHTTP.upload, multipart: body, requiresAuth: true, publicOutfitsChange: false)
            guard result.kind == scope.kind, result.ownerId == scope.ownerID else { throw UFitPhotoError.invalidResponse }
            let image = UFitProfileImage(id: result.id, url: result.url, displayUrl: result.displayUrl)
            try image.validate(); return image
        } catch let UFitAPIError.requestFailed(status, _, _) where status == UFitProfileImageHTTP.tooLarge { throw UFitPhotoError.tooLarge }
        catch is DecodingError { throw UFitPhotoError.invalidResponse }
    }
    func selectProfileImage(scope: UFitProfileImageScope, command: UFitProfileImageCommand) async throws -> UFitProfileImageReceipt {
        guard (UFitProfileImageHTTP.initialVersion..<UFitProfileImageHTTP.maximumVersion).contains(command.expectedVersion) else { throw UFitPhotoError.invalidResponse }
        do {
            let receipt: UFitProfileImageReceipt = try await send(UFitProfileImageHTTP.put, path: scope.path, body: command, requiresAuth: true, publicOutfitsChange: scope.kind != .account)
            guard receipt.requestId == command.requestId, receipt.version == command.expectedVersion + UFitProfileImageHTTP.versionStep else { throw UFitPhotoError.invalidResponse }
            return receipt
        } catch is DecodingError { throw UFitPhotoError.invalidResponse }
    }
}
