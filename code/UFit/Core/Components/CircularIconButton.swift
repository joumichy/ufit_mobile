import SwiftUI

struct CircularIconButton: View {
    let systemImage: String
    let accessibilityLabel: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 23, weight: .regular))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .background(.white.opacity(0.2), in: Circle())
            .accessibilityLabel(accessibilityLabel)
    }
}
