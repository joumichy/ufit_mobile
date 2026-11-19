import SwiftUI

/// Onyx Neige: one owner for the visual vocabulary. Media dimensions stay with their composition.
enum UFitSpace {
    static let hairline: CGFloat = 1
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let editorial: CGFloat = 40
    static let page = xl
}
enum UFitRadius {
    static let small: CGFloat = 4
    static let field: CGFloat = 4
    static let action: CGFloat = 10
    static let card: CGFloat = 6
    static let sheet: CGFloat = 16
}
enum UFitStroke {
    static let control: CGFloat = 0.75
    static let selected: CGFloat = 1
    static let focused: CGFloat = 1.5
}
enum UFitControlSize {
    static let touch: CGFloat = 44
    static let action: CGFloat = 40
    static let input: CGFloat = 48
    static let circularAction = touch
    static let icon: CGFloat = 20
    static let compactIcon: CGFloat = 16
}
enum UFitMotion {
    static let visibleOpacity = 1.0
    static let restingScale: CGFloat = 1
    static let feedback = 0.16
    static let transition = 0.28
    static let spinner = 0.9
    static let pressedScale: CGFloat = 0.985
    static let pressedOpacity = 0.78
    static let disabledOpacity = 0.42
}
enum UFitSurface {
    static let cardShadow = Color.ufitInk.opacity(0.06)
    static let elevatedShadow = Color.ufitInk.opacity(0.10)
    static let scrim = Color.ufitInk.opacity(0.40)
}
struct UFitCardSurface: ViewModifier {
    var elevated = false
    func body(content: Content) -> some View {
        content.padding(UFitSpace.md)
            .background(Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.card))
            .overlay { RoundedRectangle(cornerRadius: UFitRadius.card).stroke(Color.ufitBorder, lineWidth: UFitStroke.control) }
            .shadow(color: elevated ? UFitSurface.elevatedShadow : .clear, radius: UFitSpace.md, y: UFitSpace.xs)
    }
}
extension View {
    func ufitCard(elevated: Bool = false) -> some View { modifier(UFitCardSurface(elevated: elevated)) }
}
