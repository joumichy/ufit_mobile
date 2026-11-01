import SwiftUI

struct UFitOutfitPhotosContent: View {
    @Binding var photos: [UFitOutfitPhotoDraft]
    let error: String?
    let onAdd: () -> Void
    let onRetry: (UUID) -> Void
    let onRemove: (UUID) -> Void
    private enum Copy {
        static let title = String(localized: "Photos de la tenue"); static let add = String(localized: "Ajouter des photos")
        static let empty = String(localized: "Aucune photo"); static let sending = String(localized: "Envoi de la photo"); static let retry = String(localized: "Réessayer l’envoi")
        static let up = String(localized: "Déplacer la photo avant"); static let down = String(localized: "Déplacer la photo après"); static let remove = String(localized: "Retirer la photo")
        static let cover = String(localized: "Photo principale"); static let photo = String(localized: "Photo"); static let space = " "
    }
    private enum Layout { static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44; static let image: CGFloat = 104; static let radius: CGFloat = 12 }
    private enum Icon { static let photo = "photo"; static let up = "arrow.up"; static let down = "arrow.down" }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.title).font(.title2.weight(.medium))
            if photos.isEmpty { Text(Copy.empty).font(.callout).foregroundStyle(Color.ufitMuted) }
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                HStack(alignment: .top, spacing: Layout.gap) {
                    Group {
                        if let data = photo.previewData, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
                        else if let source = photo.source { FashionImage(source: source) }
                        else { Rectangle().fill(Color.ufitBackground).overlay { Image(systemName: Icon.photo) } }
                    }.frame(width: Layout.image, height: Layout.image).clipped().clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                        .accessibilityLabel(photoLabel(index))
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(photoLabel(index)).font(.subheadline.weight(.medium))
                        switch photo.transfer {
                        case .ready: EmptyView()
                        case .uploading: ProgressView(Copy.sending)
                        case .failed(let message):
                            Text(message).font(.caption)
                            if photo.canRetryUpload { Button(Copy.retry) { onRetry(photo.id) }.frame(minHeight: Layout.touch) }
                        }
                        HStack {
                            Button { move(photo.id, step: -UFitOutfitInput.positionStep) } label: { Image(systemName: Icon.up).frame(minWidth: Layout.touch, minHeight: Layout.touch) }.accessibilityLabel(Copy.up).disabled(index == .zero)
                            Button { move(photo.id, step: UFitOutfitInput.positionStep) } label: { Image(systemName: Icon.down).frame(minWidth: Layout.touch, minHeight: Layout.touch) }.accessibilityLabel(Copy.down).disabled(index == photos.count - UFitOutfitInput.positionStep)
                        }
                        Button(Copy.remove) { onRemove(photo.id) }.frame(minHeight: Layout.touch)
                    }
                }
                Divider()
            }
            if photos.count < UFitOutfitInput.photosMax { Button(Copy.add, action: onAdd).frame(minHeight: Layout.touch) }
            if let error { Text(error).font(.caption) }
        }
    }
    private func photoLabel(_ index: Int) -> String { index == .zero ? Copy.cover : Copy.photo + Copy.space + String(index + UFitOutfitInput.positionStep) }
    private func move(_ id: UUID, step: Int) {
        guard let index = photos.firstIndex(where: { $0.id == id }), photos.indices.contains(index + step) else { return }
        photos.swapAt(index, index + step)
    }
}
