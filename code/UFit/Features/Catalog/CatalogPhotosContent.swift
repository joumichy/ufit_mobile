import SwiftUI

struct UFitCatalogPhotosContent: View {
    @Binding var photos: [UFitCatalogPhotoDraft]
    let error: String?
    let onAdd: () -> Void
    let onRetry: (UUID) -> Void
    let onRemove: (UUID) -> Void
    private enum Copy {
        static let photos = String(localized: "Photos"); static let addPhoto = String(localized: "Ajouter des photos"); static let photoKind = String(localized: "Type de photo")
        static let emptyPhotos = String(localized: "Aucune photo"); static let sendingPhoto = String(localized: "Envoi de la photo"); static let retryPhoto = String(localized: "Réessayer l’envoi")
        static let moveUp = String(localized: "Déplacer avant"); static let moveDown = String(localized: "Déplacer après"); static let remove = String(localized: "Retirer")
        static let firstPhoto = String(localized: "Photo principale"); static let photo = String(localized: "Photo"); static let space = " "
    }
    private enum Layout { static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch; static let thumbnail: CGFloat = 96; static let radius: CGFloat = UFitRadius.field }
    private enum Position { static let first = 0; static let step = 1 }
    private enum Icon { static let photo = "photo"; static let up = "arrow.up"; static let down = "arrow.down" }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.photos).font(UFitTypography.title2.weight(.medium))
            if photos.isEmpty { Text(Copy.emptyPhotos).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                VStack(alignment: .leading, spacing: Layout.small) {
                    HStack(alignment: .top, spacing: Layout.gap) {
                        Group {
                            if let data = photo.previewData, let preview = UIImage(data: data) { Image(uiImage: preview).resizable().scaledToFill() }
                            else if let source = photo.source { FashionImage(source: source) }
                            else { UFitIcon(systemName: Icon.photo).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.ufitCanvas) }
                        }
                            .frame(width: Layout.thumbnail, height: Layout.thumbnail).clipped().clipShape(RoundedRectangle(cornerRadius: Layout.radius)).accessibilityLabel(photo.kind.label)
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(index == Position.first ? Copy.firstPhoto : Copy.photo + Copy.space + String(index + Position.step)).font(UFitTypography.subheadline.weight(.medium))
                            Text(Copy.photoKind).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                            UFitSelection(Copy.photoKind, selection: Binding(get: { photo.kind }, set: { kind in if let position = photos.firstIndex(where: { $0.id == photo.id }) { photos[position].kind = kind } }), options: UFitCatalogImageKind.allCases.map { .init(value: $0, title: $0.label) }).frame(minHeight: Layout.touch)
                        }
                    }
                    switch photo.transfer {
                    case .ready: EmptyView()
                    case .uploading: UFitLoading(Copy.sendingPhoto)
                    case .failed(let error):
                        UFitFieldError(message: error)
                        if photo.canRetryUpload { UFitButton(Copy.retryPhoto) { onRetry(photo.id) }.frame(minHeight: Layout.touch) }
                    }
                    HStack {
                        UFitButton { photos.swapAt(index, index - Position.step) } label: { UFitIcon(systemName: Icon.up).frame(minWidth: Layout.touch, minHeight: Layout.touch) }.accessibilityLabel(Copy.moveUp).disabled(index == Position.first)
                        UFitButton { photos.swapAt(index, index + Position.step) } label: { UFitIcon(systemName: Icon.down).frame(minWidth: Layout.touch, minHeight: Layout.touch) }.accessibilityLabel(Copy.moveDown).disabled(index == photos.count - Position.step)
                        Spacer()
                        UFitButton(Copy.remove) { onRemove(photo.id) }.frame(minHeight: Layout.touch)
                    }
                    Divider()
                }
            }
            if photos.count < UFitCatalogInput.photosMax { UFitButton(Copy.addPhoto, action: onAdd).frame(minHeight: Layout.touch) }
            if let error { UFitFieldError(message: error) }
        }
    }
}
