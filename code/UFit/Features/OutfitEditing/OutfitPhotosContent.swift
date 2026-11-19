import SwiftUI

struct UFitOutfitPhotosContent: View {
    @Binding var photos: [UFitOutfitPhotoDraft]
    let error: String?
    let onAdd: () -> Void
    let onRetry: (UUID) -> Void
    let onRemove: (UUID) -> Void
    var onPins: ((UUID) -> Void)? = nil
    var renewPhotoSource: ((UUID) async throws -> String)? = nil
    @State private var reorderCollectionID = UUID()
    private enum Copy {
        static let title = String(localized: "Photos de la tenue"); static let add = String(localized: "Ajouter des photos")
        static let empty = String(localized: "Aucune photo"); static let sending = String(localized: "Envoi de la photo"); static let retry = String(localized: "Réessayer l’envoi")
        static let remove = String(localized: "Retirer la photo")
        static let pins = String(localized: "Placer les repères")
        static let cover = String(localized: "Photo principale"); static let photo = String(localized: "Photo"); static let space = " "; static let separator = " · "
    }
    private enum Layout { static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch; static let image: CGFloat = 104; static let radius: CGFloat = UFitRadius.field }
    private enum Icon { static let photo = "photo"; static let add = "photo.badge.plus"; static let pins = "scope"; static let remove = "trash" }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            HStack(alignment: .center, spacing: Layout.small) {
                Text(Copy.title).font(UFitTypography.title2.weight(.medium)).accessibilityAddTraits(.isHeader)
                Spacer(minLength: .zero)
                if photos.count < UFitOutfitInput.photosMax {
                    UFitButton(action: onAdd) { UFitIcon(systemName: Icon.add).font(UFitTypography.icon).frame(width: Layout.touch, height: Layout.touch) }
                        .accessibilityLabel(Copy.add)
                }
            }
            if photos.isEmpty { Text(Copy.empty).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
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
                            else { Rectangle().fill(Color.ufitCanvas).overlay { UFitIcon(systemName: Icon.photo) } }
                        }.frame(width: Layout.image, height: Layout.image).clipped().clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                            .modifier(UFitPhotoReorderSource(photoID: photo.id, collectionID: reorderCollectionID, count: photos.count))
                        Text(photoLabel(index)).font(UFitTypography.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(spacing: .zero) {
                            if let onPins {
                                UFitButton { onPins(photo.id) } label: { UFitIcon(systemName: Icon.pins).font(UFitTypography.icon).frame(width: Layout.touch, height: Layout.touch) }
                                    .accessibilityLabel(Copy.pins + Copy.separator + photoLabel(index)).disabled(photo.transfer != .ready)
                            }
                            UFitButton(role: .destructive) { onRemove(photo.id) } label: { UFitIcon(systemName: Icon.remove).font(UFitTypography.icon).frame(width: Layout.touch, height: Layout.touch) }
                                .accessibilityLabel(Copy.remove + Copy.separator + photoLabel(index))
                        }
                    }.modifier(UFitPhotoReorderDestination(photoID: photo.id, collectionID: reorderCollectionID, photos: $photos))
                    switch photo.transfer {
                    case .ready: EmptyView()
                    case .uploading: UFitLoading(Copy.sending)
                    case .failed(let message):
                        UFitFieldError(message: message)
                        if photo.canRetryUpload { UFitButton(Copy.retry) { onRetry(photo.id) }.ufitButtonStyle(.secondary, compact: true) }
                    }
                    Divider()
                }
            }
            if let error { UFitFieldError(message: error) }
        }
    }
    private func photoLabel(_ index: Int) -> String { index == .zero ? Copy.cover : Copy.photo + Copy.space + String(index + UFitOutfitInput.positionStep) }
}
