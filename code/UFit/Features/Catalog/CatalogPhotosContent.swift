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
    private enum Layout { static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44; static let thumbnail: CGFloat = 96; static let radius: CGFloat = 12 }
    private enum Position { static let first = 0; static let step = 1 }
    private enum Icon { static let photo = "photo"; static let up = "arrow.up"; static let down = "arrow.down" }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.photos).font(.title2.weight(.medium))
            if photos.isEmpty { Text(Copy.emptyPhotos).font(.callout).foregroundStyle(Color.ufitMuted) }
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                VStack(alignment: .leading, spacing: Layout.small) {
                    HStack(alignment: .top, spacing: Layout.gap) {
                        Group {
                            if let data = photo.previewData, let preview = UIImage(data: data) { Image(uiImage: preview).resizable().scaledToFill() }
                            else if let source = photo.source { FashionImage(source: source) }
                            else { Image(systemName: Icon.photo).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.ufitBackground) }
                        }
                            .frame(width: Layout.thumbnail, height: Layout.thumbnail).clipped().clipShape(RoundedRectangle(cornerRadius: Layout.radius)).accessibilityLabel(photo.kind.label)
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(index == Position.first ? Copy.firstPhoto : Copy.photo + Copy.space + String(index + Position.step)).font(.subheadline.weight(.medium))
                            Text(Copy.photoKind).font(.caption).foregroundStyle(Color.ufitMuted)
                            Picker(Copy.photoKind, selection: Binding(get: { photo.kind }, set: { kind in if let position = photos.firstIndex(where: { $0.id == photo.id }) { photos[position].kind = kind } })) {
                                ForEach(UFitCatalogImageKind.allCases) { Text($0.label).tag($0) }
                            }.pickerStyle(.menu).frame(minHeight: Layout.touch)
                        }
                    }
                    switch photo.transfer {
                    case .ready: EmptyView()
                    case .uploading: ProgressView(Copy.sendingPhoto)
                    case .failed(let error):
                        Text(error).font(.caption)
                        if photo.canRetryUpload { Button(Copy.retryPhoto) { onRetry(photo.id) }.frame(minHeight: Layout.touch) }
                    }
                    HStack {
                        Button { photos.swapAt(index, index - Position.step) } label: { Image(systemName: Icon.up).frame(minWidth: Layout.touch, minHeight: Layout.touch) }.accessibilityLabel(Copy.moveUp).disabled(index == Position.first)
                        Button { photos.swapAt(index, index + Position.step) } label: { Image(systemName: Icon.down).frame(minWidth: Layout.touch, minHeight: Layout.touch) }.accessibilityLabel(Copy.moveDown).disabled(index == photos.count - Position.step)
                        Spacer()
                        Button(Copy.remove) { onRemove(photo.id) }.frame(minHeight: Layout.touch)
                    }
                    Divider()
                }
            }
            if photos.count < UFitCatalogInput.photosMax { Button(Copy.addPhoto, action: onAdd).frame(minHeight: Layout.touch) }
            if let error { Text(error).font(.caption) }
        }
    }
}
