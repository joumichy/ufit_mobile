import SwiftUI

/// Draft photos also have an in-memory image before their upload completes.
struct UFitOutfitDraftPhotoPages: View {
    let photos: [UFitOutfitPhotoDraft]
    @Binding var selection: UUID?
    var renewSource: ((UUID) async throws -> String)? = nil
    private enum Copy {
        static func page(_ position: Int, count: Int) -> String { String(localized: "Photo \(position) sur \(count)") }
        static let preparing = String(localized: "Préparation de la photo")
        static let failed = String(localized: "Photo indisponible")
        static let photo = "photo"
    }
    var body: some View {
        TabView(selection: $selection) {
            ForEach(photos) { photo in
                Group {
                    if photo.source == nil && photo.previewData == nil {
                        switch photo.transfer {
                        case .uploading: UFitLoading(Copy.preparing).foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
                        case .failed(let message): UFitEmptyState(title: Copy.failed, message: message, symbol: Copy.photo).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.ufitCanvas)
                        case .ready: UFitEmptyState(title: Copy.failed, symbol: Copy.photo).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.ufitCanvas)
                        }
                    } else {
                        UFitPinnedPhotoContent(source: photo.source, previewData: photo.previewData, pins: [], onPin: { _ in },
                            renewSource: renewSource.map { renew in { () async throws -> String in try await renew(photo.id) } })
                            .accessibilityLabel(Copy.page((photos.firstIndex(where: { $0.id == photo.id }) ?? .zero) + UFitOutfitInput.positionStep, count: photos.count))
                    }
                }.background(Color.black)
                    .tag(Optional(photo.id))
            }
        }.tabViewStyle(.page(indexDisplayMode: .never))
    }
}
