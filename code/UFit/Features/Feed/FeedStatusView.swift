import SwiftUI

enum UFitFeedStatus {
    case loading, empty, failed(String)
}

struct UFitFeedStatusView: View {
    let status: UFitFeedStatus
    let onRetry: () -> Void
    private enum Copy {
        static let empty = String(localized: "Aucune tenue disponible")
        static let error = String(localized: "La sélection est indisponible")
        static let retry = String(localized: "Actualiser")
        static let emptyIcon = "square.grid.2x2"
        static let errorIcon = "wifi.exclamationmark"
    }
    private enum Layout {
        static let spacing: CGFloat = UFitSpace.xl
        static let icon: CGFloat = 36
        static let padding: CGFloat = UFitSpace.xxl
    }
    var body: some View {
        VStack(spacing: Layout.spacing) {
            switch status {
            case .loading: UFitLoading()
            case .empty:
                UFitIcon(systemName: Copy.emptyIcon).ufitFont(size: Layout.icon, weight: .ultraLight)
                Text(Copy.empty).font(UFitTypography.title2).multilineTextAlignment(.center)
                retry
            case .failed(let message):
                UFitIcon(systemName: Copy.errorIcon).ufitFont(size: Layout.icon, weight: .ultraLight)
                Text(Copy.error).font(UFitTypography.title2).multilineTextAlignment(.center)
                Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).multilineTextAlignment(.center)
                retry
            }
        }
        .padding(Layout.padding).frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private var retry: some View {
        UFitButton(Copy.retry, action: onRetry).ufitButtonStyle(.primary, compact: true)
    }
}
