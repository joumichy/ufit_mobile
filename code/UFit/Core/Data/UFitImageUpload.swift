import Foundation

enum UFitImageUploadContract {
    static let mime = "image/jpeg"
    static let maximumBytes = 8 * 1024 * 1024
    static let file = "file"; static let filename = "photo.jpg"
}
enum UFitPhotoError: LocalizedError {
    case invalidImage, tooLarge, invalidResponse
    var errorDescription: String? {
        switch self {
        case .invalidImage: String(localized: "Cette photo ne peut pas être ouverte. Choisissez une autre image.")
        case .tooLarge: String(localized: "Cette photo reste trop volumineuse. Choisissez une image plus légère.")
        case .invalidResponse: String(localized: "L’envoi n’a pas pu être confirmé. Réessayez cette photo.")
        }
    }
}
enum UFitMultipartEncoding {
    static let lineBreak = "\r\n"; static let delimiter = "--"
    static let contentType = "multipart/form-data; boundary="
    static let disposition = "Content-Disposition: form-data; name=\""
    static let filename = "\"; filename=\""; static let quote = "\""
    static let mimeHeader = "Content-Type: "
    static let allowedSchemes = ["https", "http"]
    static func image(fields: [(String, String)], jpeg: Data) -> UFitMultipartBody {
        file(fields: fields, bytes: jpeg, name: UFitImageUploadContract.filename, mime: UFitImageUploadContract.mime)
    }
    static func file(fields: [(String, String)], bytes: Data, name: String, mime: String) -> UFitMultipartBody {
        let boundary = UUID().uuidString
        var data = Data()
        func line(_ text: String) { data.append(contentsOf: (text + lineBreak).utf8) }
        for (name, value) in fields {
            line(delimiter + boundary); line(disposition + name + quote); line(String()); line(value)
        }
        line(delimiter + boundary)
        line(disposition + UFitImageUploadContract.file + filename + name + quote)
        line(mimeHeader + mime); line(String()); data.append(bytes); line(String()); line(delimiter + boundary + delimiter)
        return .init(data: data, contentType: contentType + boundary)
    }
}
