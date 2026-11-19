import SwiftUI

struct UFitCatalogPhotosContent: View {
    @Binding var photos: [UFitCatalogPhotoDraft]
    let error: String?
    let onAdd: () -> Void
    let onRetry: (UUID) -> Void
    let onRemove: (UUID) -> Void
    var renewPhotoSource: ((UUID) async throws -> String)? = nil
    @State private var reorderCollectionID = UUID()
    private enum Copy {
        static let photos = String(localized: "Photos"); static let addPhoto = String(localized: "Ajouter des photos"); static let photoKind = String(localized: "Type de photo")
        static let emptyPhotos = String(localized: "Aucune photo"); static let sendingPhoto = String(localized: "Envoi de la photo"); static let retryPhoto = String(localized: "Réessayer l’envoi")
        static let remove = String(localized: "Retirer")
        static let firstPhoto = String(localized: "Photo principale"); static let photo = String(localized: "Photo"); static let space = " "; static let separator = " · "
    }
    private enum Layout { static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch; static let thumbnail: CGFloat = 96; static let radius: CGFloat = UFitRadius.field }
    private enum Position { static let first = 0; static let step = 1 }
    private enum Icon { static let photo = "photo"; static let add = "photo.badge.plus"; static let remove = "trash" }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            HStack(alignment: .center, spacing: Layout.small) {
                Text(Copy.photos).font(UFitTypography.title2.weight(.medium)).accessibilityAddTraits(.isHeader)
                Spacer(minLength: .zero)
                if photos.count < UFitCatalogInput.photosMax {
                    UFitButton(action: onAdd) { UFitIcon(systemName: Icon.add).font(UFitTypography.icon).frame(width: Layout.touch, height: Layout.touch) }
                        .accessibilityLabel(Copy.addPhoto)
                }
            }
            if photos.isEmpty { Text(Copy.emptyPhotos).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                VStack(alignment: .leading, spacing: Layout.small) {
                    HStack(alignment: .top, spacing: Layout.small) {
                        UFitPhotoOrderControls(photoLabel: photoLabel(index), position: index, count: photos.count) { step in
                            UFitPhotoOrdering.move(photo.id, by: step, in: &photos)
                        }
                        Group {
                            if photo.previewData != nil || photo.source != nil {
                                UFitPinnedPhotoContent(source: photo.source, previewData: photo.previewData, pins: [], surface: .neutral, onPin: { _ in },
                                    renewSource: renewPhotoSource.map { renew in { () async throws -> String in try await renew(photo.id) } }, showsRetryLabel: false, imageAccessibilityLabel: photoLabel(index))
                            }
                            else { UFitIcon(systemName: Icon.photo).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.ufitCanvas) }
                        }
                            .frame(width: Layout.thumbnail, height: Layout.thumbnail).clipped().clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                            .modifier(UFitPhotoReorderSource(photoID: photo.id, collectionID: reorderCollectionID, count: photos.count))
                        Text(photoLabel(index)).font(UFitTypography.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        UFitButton(role: .destructive) { onRemove(photo.id) } label: { UFitIcon(systemName: Icon.remove).font(UFitTypography.icon).frame(width: Layout.touch, height: Layout.touch) }
                            .accessibilityLabel(Copy.remove + Copy.separator + photoLabel(index))
                    }.modifier(UFitPhotoReorderDestination(photoID: photo.id, collectionID: reorderCollectionID, photos: $photos))
                    UFitFilterChoices(title: Copy.photoKind + Copy.separator + photoLabel(index),
                        selection: Binding(get: { photo.kind }, set: { kind in if let position = photos.firstIndex(where: { $0.id == photo.id }) { photos[position].kind = kind } }),
                        options: UFitCatalogImageKind.allCases.map { .init(value: $0, title: $0.label) })
                    switch photo.transfer {
                    case .ready: EmptyView()
                    case .uploading: UFitLoading(Copy.sendingPhoto)
                    case .failed(let error):
                        UFitFieldError(message: error)
                        if photo.canRetryUpload { UFitButton(Copy.retryPhoto) { onRetry(photo.id) }.ufitButtonStyle(.secondary, compact: true) }
                    }
                    Divider()
                }
            }
            if let error { UFitFieldError(message: error) }
        }
    }
    private func photoLabel(_ index: Int) -> String { index == Position.first ? Copy.firstPhoto : Copy.photo + Copy.space + String(index + Position.step) }
}
