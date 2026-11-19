import SwiftUI

struct UFitNotificationDeviceContent: View {
    let permission: UFitNotificationPermission
    let phase: UFitNotificationDevicePhase
    let isBusy: Bool
    let message: String?
    let onAction: () -> Void
    private typealias Copy = UFitNotificationDeviceCopy
    private var detail: String {
        switch permission {
        case .unknown: Copy.checking
        case .notAsked: Copy.notAsked
        case .denied: Copy.denied
        case .allowed:
            switch phase {
            case .waitingForToken: Copy.token
            case .linking: Copy.linking
            case .linked: Copy.linked
            case .idle, .failed: Copy.allowed
            }
        }
    }
    private var action: String {
        switch permission { case .notAsked: Copy.authorize; case .denied: Copy.settings; case .allowed, .unknown: Copy.retry }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.sm) {
            Text(Copy.title).font(UFitTypography.headline)
            Text(detail).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            if let message { UFitNotice(message: message, kind: .error) }
            if permission != .allowed || phase != .linked {
                UFitActionButton(title: action, kind: .secondary, isBusy: isBusy, action: onAction)
            } else { UFitButton(Copy.settings, action: onAction).ufitButtonStyle(.text) }
        }
    }
}
