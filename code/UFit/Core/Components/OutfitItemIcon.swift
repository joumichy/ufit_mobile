import SwiftUI

/// Category comes from the piece contract, never from a product title or photo.
struct UFitOutfitItemIcon: View {
    let type: UFitOutfitItemType
    var size: CGFloat = Layout.size
    private enum Layout { static let size: CGFloat = 23; static let stroke: CGFloat = 1.5 }
    var body: some View {
        UFitOutfitItemGlyph(type: type)
            .stroke(style: StrokeStyle(lineWidth: Layout.stroke, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
