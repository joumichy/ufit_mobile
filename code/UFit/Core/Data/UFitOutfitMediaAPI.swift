import Foundation

enum UFitOutfitMediaHTTP {
    static let upload = "media/outfit-uploads"; static let root = "media/outfit-assets/"
    static let image = "/image"; static let privateRead = "/private"; static let request = "requestId"
    static let tooLarge = 413
}
struct UFitUploadedOutfitPhoto: Decodable {
    let id: String; let url: String; let displayUrl: String
    @UFitRequiredNullable var creatorId: String?
    @UFitRequiredNullable var brandId: String?
    func validate(scope: UFitOutfitScope, baseURL: URL, expectedID: String? = nil) throws {
        let stable = baseURL.appendingPathComponent(UFitOutfitMediaHTTP.root + id + UFitOutfitMediaHTTP.image)
        guard UUID(uuidString: id) != nil, expectedID == nil || id == expectedID, stable.absoluteString == url,
              scope.kind == .creator ? creatorId == scope.profileID && brandId == nil : brandId == scope.profileID && creatorId == nil,
              let display = URL(string: displayUrl), let scheme = display.scheme, UFitMultipartEncoding.allowedSchemes.contains(scheme),
              display.host != nil, display.user == nil, display.password == nil else { throw UFitPhotoError.invalidResponse }
    }
}
extension UFitAPIClient {
    func uploadOutfitPhoto(scope: UFitOutfitScope, requestID: UUID, jpeg: Data) async throws -> UFitUploadedOutfitPhoto {
        guard UUID(uuidString: scope.profileID) != nil else { throw UFitPhotoError.invalidResponse }
        guard !jpeg.isEmpty else { throw UFitPhotoError.invalidImage }
        guard jpeg.count <= UFitImageUploadContract.maximumBytes else { throw UFitPhotoError.tooLarge }
        let owner = UFitOutfitEditingHTTP.ownerQuery(scope)
        let body = UFitMultipartEncoding.image(fields: [(owner.name, scope.profileID), (UFitOutfitMediaHTTP.request, requestID.uuidString)], jpeg: jpeg)
        let result: UFitUploadedOutfitPhoto
        do { result = try await send(UFitOutfitEditingHTTP.post, path: UFitOutfitMediaHTTP.upload, multipart: body, requiresAuth: true, publicOutfitsChange: false) }
        catch let UFitAPIError.requestFailed(status, _, _) where status == UFitOutfitMediaHTTP.tooLarge { throw UFitPhotoError.tooLarge }
        try result.validate(scope: scope, baseURL: configuration.baseURL); return result
    }
    func fetchOwnedOutfitPhoto(scope: UFitOutfitScope, url: String) async throws -> UFitUploadedOutfitPhoto {
        guard let source = URL(string: url) else { throw UFitPhotoError.invalidResponse }
        let id = source.deletingLastPathComponent().lastPathComponent
        guard UUID(uuidString: id) != nil else { throw UFitPhotoError.invalidResponse }
        let stable = configuration.baseURL.appendingPathComponent(UFitOutfitMediaHTTP.root + id + UFitOutfitMediaHTTP.image)
        guard stable.absoluteString == url else { throw UFitPhotoError.invalidResponse }
        let result: UFitUploadedOutfitPhoto = try await send(UFitOutfitEditingHTTP.get, path: UFitOutfitMediaHTTP.root + id + UFitOutfitMediaHTTP.privateRead, requiresAuth: true)
        try result.validate(scope: scope, baseURL: configuration.baseURL, expectedID: id); return result
    }
}
