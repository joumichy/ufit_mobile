import Foundation

struct UFitMultipartBody { let data: Data; let contentType: String }
enum UFitProductPhotoContract {
    static let mime = "image/jpeg"
    static let maximumBytes = 8 * 1024 * 1024
    static let upload = "media/product-uploads"
    static let root = "media"; static let assets = "assets"; static let image = "image"; static let privateRead = "private"
    static let brand = "brandId"; static let request = "requestId"; static let file = "file"; static let filename = "photo.jpg"
    static let post = "POST"; static let get = "GET"; static let pathSeparator = "/"; static let tooLargeStatus = 413
}
enum UFitProductPhotoError: LocalizedError {
    case invalidImage, tooLarge, invalidResponse
    var errorDescription: String? {
        switch self {
        case .invalidImage: String(localized: "Cette photo ne peut pas être ouverte. Choisissez une autre image.")
        case .tooLarge: String(localized: "Cette photo reste trop volumineuse. Choisissez une image plus légère.")
        case .invalidResponse: String(localized: "L’envoi n’a pas pu être confirmé. Réessayez cette photo.")
        }
    }
}
struct UFitUploadedProductPhoto: Decodable { let id: String; let brandId: String; let url: String; let displayUrl: String }
private enum MultipartEncoding {
    static let lineBreak = "\r\n"; static let delimiter = "--"
    static let contentType = "multipart/form-data; boundary="
    static let disposition = "Content-Disposition: form-data; name=\""
    static let filename = "\"; filename=\""; static let quote = "\""
    static let mimeHeader = "Content-Type: "
    static let allowedSchemes = ["https", "http"]
    static func productPhoto(brandID: String, requestID: UUID, jpeg: Data) -> UFitMultipartBody {
        let boundary = UUID().uuidString
        var data = Data()
        func line(_ text: String) { data.append(contentsOf: (text + lineBreak).utf8) }
        for (name, value) in [(UFitProductPhotoContract.brand, brandID), (UFitProductPhotoContract.request, requestID.uuidString)] {
            line(delimiter + boundary); line(disposition + name + quote); line(String()); line(value)
        }
        line(delimiter + boundary)
        line(disposition + UFitProductPhotoContract.file + filename + UFitProductPhotoContract.filename + quote)
        line(mimeHeader + UFitProductPhotoContract.mime); line(String()); data.append(jpeg); line(String()); line(delimiter + boundary + delimiter)
        return .init(data: data, contentType: contentType + boundary)
    }
}
extension UFitAPIClient {
    func fetchOwnedProductPhoto(brandID: String, url: String) async throws -> UFitUploadedProductPhoto {
        guard let source = URL(string: url) else { throw UFitProductPhotoError.invalidResponse }
        let id = source.deletingLastPathComponent().lastPathComponent
        guard UUID(uuidString: id) != nil, url == productPhotoURL(id: id).absoluteString else { throw UFitProductPhotoError.invalidResponse }
        let path = [UFitProductPhotoContract.root, UFitProductPhotoContract.assets, id, UFitProductPhotoContract.privateRead].joined(separator: UFitProductPhotoContract.pathSeparator)
        let result: UFitUploadedProductPhoto = try await send(UFitProductPhotoContract.get, path: path, requiresAuth: true)
        guard result.id == id else { throw UFitProductPhotoError.invalidResponse }
        try validateProductPhoto(result, brandID: brandID)
        return result
    }
    func uploadProductPhoto(brandID: String, requestID: UUID, jpeg: Data) async throws -> UFitUploadedProductPhoto {
        guard UUID(uuidString: brandID) != nil else { throw UFitProductPhotoError.invalidResponse }
        guard !jpeg.isEmpty else { throw UFitProductPhotoError.invalidImage }
        guard jpeg.count <= UFitProductPhotoContract.maximumBytes else { throw UFitProductPhotoError.tooLarge }
        let result: UFitUploadedProductPhoto
        do {
            result = try await send(UFitProductPhotoContract.post, path: UFitProductPhotoContract.upload,
                multipart: MultipartEncoding.productPhoto(brandID: brandID, requestID: requestID, jpeg: jpeg), requiresAuth: true)
        } catch let UFitAPIError.requestFailed(status, _, _) where status == UFitProductPhotoContract.tooLargeStatus { throw UFitProductPhotoError.tooLarge }
        try validateProductPhoto(result, brandID: brandID)
        return result
    }
    private func productPhotoURL(id: String) -> URL {
        [UFitProductPhotoContract.root, UFitProductPhotoContract.assets, id, UFitProductPhotoContract.image]
            .reduce(configuration.baseURL) { $0.appendingPathComponent($1) }
    }
    private func validateProductPhoto(_ result: UFitUploadedProductPhoto, brandID: String) throws {
        guard UUID(uuidString: result.id) != nil, result.brandId == brandID, result.url == productPhotoURL(id: result.id).absoluteString,
              let display = URL(string: result.displayUrl), let scheme = display.scheme, MultipartEncoding.allowedSchemes.contains(scheme),
              display.host != nil, display.user == nil, display.password == nil else { throw UFitProductPhotoError.invalidResponse }
    }
}
