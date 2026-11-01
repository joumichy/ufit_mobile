import UIKit

enum UFitCatalogPhotoEncoding {
    private static let maximumEdge: CGFloat = 2048
    private static let pixelScale: CGFloat = 1
    private static let quality: CGFloat = 0.85
    static func jpeg(_ bytes: Data) throws -> Data {
        guard let image = UIImage(data: bytes), image.size.width > .zero, image.size.height > .zero else { throw UFitProductPhotoError.invalidImage }
        let scale = min(pixelScale, maximumEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = pixelScale; format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let bounds = CGRect(origin: .zero, size: size)
            UIColor.white.setFill(); context.fill(bounds); image.draw(in: bounds)
        }
        guard let jpeg = rendered.jpegData(compressionQuality: quality) else { throw UFitProductPhotoError.invalidImage }
        guard jpeg.count <= UFitProductPhotoContract.maximumBytes else { throw UFitProductPhotoError.tooLarge }
        return jpeg
    }
}
