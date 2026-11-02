import SwiftUI

struct UFitProfilePhoto: View {
    let source: String?
    var previewData: Data?
    let size: CGFloat
    var isLogo = false
    let onRetry: () async -> Void
    @State private var reloadID = UUID()
    private enum Layout { static let circleDivisor: CGFloat = 2; static let icon: CGFloat = UFitTypography.Size.section }
    private enum Icon { static let person = "person"; static let brand = "building.2"; static let retry = "arrow.clockwise"; static let invalid = "photo.badge.exclamationmark" }
    private enum Copy {
        static let retry = String(localized: "Recharger la photo")
        static let photo = String(localized: "Photo de profil")
        static let logo = String(localized: "Logo de la marque")
        static let invalid = String(localized: "Photo indisponible")
    }
    var body: some View {
        Group {
            if let previewData {
                if let image = UIImage(data: previewData) { fitted(Image(uiImage: image)) }
                else { UFitIcon(systemName: Icon.invalid).accessibilityLabel(Copy.invalid) }
            } else if let source, let url = URL(string: source) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): fitted(image)
                    case .empty: UFitLoading()
                    case .failure:
                        UFitButton {
                            Task { await onRetry(); reloadID = UUID() }
                        } label: { UFitIcon(systemName: Icon.retry).frame(minWidth: UFitControlSize.touch, minHeight: UFitControlSize.touch) }
                            .accessibilityLabel(Copy.retry)
                    @unknown default: UFitIcon(systemName: Icon.invalid).accessibilityLabel(Copy.invalid)
                    }
                }.id(reloadID)
            } else {
                UFitIcon(systemName: isLogo ? Icon.brand : Icon.person).ufitFont(size: Layout.icon, weight: .light).foregroundStyle(Color.ufitSecondaryText)
                    .accessibilityLabel(isLogo ? Copy.logo : Copy.photo)
            }
        }
        .frame(width: size, height: size).background(Color.ufitSecondary)
        .clipShape(RoundedRectangle(cornerRadius: isLogo ? UFitRadius.field : size / Layout.circleDivisor))
    }
    private func fitted(_ image: Image) -> some View {
        image.resizable().aspectRatio(contentMode: isLogo ? .fit : .fill)
            .accessibilityElement(children: .ignore).accessibilityLabel(isLogo ? Copy.logo : Copy.photo)
            .accessibilityAddTraits(.isImage).accessibilityHidden(false)
    }
}
