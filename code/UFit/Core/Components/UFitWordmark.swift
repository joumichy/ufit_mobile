import SwiftUI

/// The existing Ufit typographic signature, shared by its entry and account forms.
struct UFitWordmark: View {
    enum Size { case compact, display }
    var size: Size = .compact
    var color: Color = .ufitInk
    private enum Brand {
        static let letters = "UFIT"
        static let accessibleName = "Ufit"
        static let displaySize: CGFloat = 68
        static let compactTracking: CGFloat = 7
        static let displayTracking: CGFloat = 12
        static let minimumScale: CGFloat = 0.35
    }
    var body: some View {
        Text(Brand.letters)
            .ufitFont(size: size == .display ? Brand.displaySize : UFitTypography.Size.section, weight: .semibold)
            .tracking(size == .display ? Brand.displayTracking : Brand.compactTracking)
            .foregroundStyle(color).lineLimit(1).minimumScaleFactor(Brand.minimumScale)
            .accessibilityLabel(Brand.accessibleName)
    }
}
