import Foundation

struct UFitMultipartBody { let data: Data; let contentType: String }
enum UFitProductPhotoContract {
    static let upload = "media/product-uploads"
    static let root = "media"; static let assets = "assets"; static let image = "image"; static let privateRead = "private"
    static let brand = "brandId"; static let request = "requestId"
    static let post = "POST"; static let get = "GET"; static let pathSeparator = "/"; static let tooLargeStatus = 413
}
struct UFitUploadedProductPhoto: Decodable { let id: String; let brandId: String; let url: String; let displayUrl: String }
extension UFitAPIClient {
    func fetchOwnedProductPhoto(brandID: String, url: String) async throws -> UFitUploadedProductPhoto {
        guard let source = URL(string: url) else { throw UFitPhotoError.invalidResponse }
        let id = source.deletingLastPathComponent().lastPathComponent
        guard UUID(uuidString: id) != nil, url == productPhotoURL(id: id).absoluteString else { throw UFitPhotoError.invalidResponse }
        let path = [UFitProductPhotoContract.root, UFitProductPhotoContract.assets, id, UFitProductPhotoContract.privateRead].joined(separator: UFitProductPhotoContract.pathSeparator)
        let result: UFitUploadedProductPhoto = try await send(UFitProductPhotoContract.get, path: path, requiresAuth: true)
        guard result.id == id else { throw UFitPhotoError.invalidResponse }
        try validateProductPhoto(result, brandID: brandID)
        return result
    }
    func uploadProductPhoto(brandID: String, requestID: UUID, jpeg: Data) async throws -> UFitUploadedProductPhoto {
        guard UUID(uuidString: brandID) != nil else { throw UFitPhotoError.invalidResponse }
        guard !jpeg.isEmpty else { throw UFitPhotoError.invalidImage }
        guard jpeg.count <= UFitImageUploadContract.maximumBytes else { throw UFitPhotoError.tooLarge }
        let result: UFitUploadedProductPhoto
        do {
            result = try await send(UFitProductPhotoContract.post, path: UFitProductPhotoContract.upload,
                multipart: UFitMultipartEncoding.image(fields: [(UFitProductPhotoContract.brand, brandID), (UFitProductPhotoContract.request, requestID.uuidString)], jpeg: jpeg), requiresAuth: true, publicOutfitsChange: false)
        } catch let UFitAPIError.requestFailed(status, _, _) where status == UFitProductPhotoContract.tooLargeStatus { throw UFitPhotoError.tooLarge }
        try validateProductPhoto(result, brandID: brandID)
        return result
    }
    private func productPhotoURL(id: String) -> URL {
        [UFitProductPhotoContract.root, UFitProductPhotoContract.assets, id, UFitProductPhotoContract.image]
            .reduce(configuration.baseURL) { $0.appendingPathComponent($1) }
    }
    private func validateProductPhoto(_ result: UFitUploadedProductPhoto, brandID: String) throws {
        guard UUID(uuidString: result.id) != nil, result.brandId == brandID, result.url == productPhotoURL(id: result.id).absoluteString,
              let display = URL(string: result.displayUrl), let scheme = display.scheme, UFitMultipartEncoding.allowedSchemes.contains(scheme),
              display.host != nil, display.user == nil, display.password == nil else { throw UFitPhotoError.invalidResponse }
    }
}
