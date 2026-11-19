import SwiftUI

struct CircularIconButton: View {
    let systemImage: String
    let accessibilityLabel: String

    var body: some View {
        UFitIcon(systemName: systemImage)
            .font(UFitTypography.icon)
            .foregroundStyle(.white)
            .frame(width: UFitControlSize.circularAction, height: UFitControlSize.circularAction)
            .background(.white.opacity(0.2), in: Circle())
            .accessibilityLabel(accessibilityLabel)
    }
}
