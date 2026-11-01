import Foundation

enum UFitPhotoTransfer: Codable, Equatable { case ready, uploading, failed(String) }
