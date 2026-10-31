import SwiftUI

enum UFitFeedStatus {
    case loading, empty, failed(String)
}

struct UFitFeedStatusView: View {
    let status: UFitFeedStatus
    let onRetry: () -> Void
    private enum Copy {
        static let empty = String(localized: "La sélection arrive bientôt")
        static let error = String(localized: "La sélection est indisponible")
        static let retry = String(localized: "Actualiser")
        static let emptyIcon = "square.grid.2x2"
        static let errorIcon = "wifi.exclamationmark"
    }
    private enum Layout {
        static let spacing: CGFloat = 24
        static let icon: CGFloat = 36
        static let padding: CGFloat = 32
    }
    var body: some View {
        VStack(spacing: Layout.spacing) {
            switch status {
            case .loading: ProgressView()
            case .empty:
                Image(systemName: Copy.emptyIcon).font(.system(size: Layout.icon, weight: .ultraLight))
                Text(Copy.empty).font(.title2).multilineTextAlignment(.center)
                retry
            case .failed(let message):
                Image(systemName: Copy.errorIcon).font(.system(size: Layout.icon, weight: .ultraLight))
                Text(Copy.error).font(.title2).multilineTextAlignment(.center)
                Text(message).font(.callout).foregroundStyle(Color.ufitMuted).multilineTextAlignment(.center)
                retry
            }
        }
        .padding(Layout.padding).frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color.ufitInk).background(Color.ufitBackground)
    }
    private var retry: some View {
        Button(Copy.retry, action: onRetry).buttonStyle(CompactPrimaryButtonStyle())
    }
}
