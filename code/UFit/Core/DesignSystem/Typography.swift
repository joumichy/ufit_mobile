import SwiftUI

enum UFitTypography {
    static let icon = Font.system(size: UFitControlSize.icon)
    static let largeTitle = Font.largeTitle
    static let editorialTitle = Font.system(.largeTitle, design: .serif)
    static let title = Font.title
    static let title2 = Font.title2
    static let title3 = Font.title3
    static let headline = Font.system(.body, weight: .medium)
    static let action = Font.system(.subheadline, weight: .regular)
    static let actionStrong = Font.system(.subheadline, weight: .medium)
    static let subheadline = Font.subheadline
    static let body = Font.body
    static let callout = Font.callout
    static let footnote = Font.footnote
    static let caption = Font.caption
    static let caption2 = Font.caption2
    enum Size {
        static let micro: CGFloat = 11
        static let caption: CGFloat = 12
        static let small: CGFloat = 14
        static let body: CGFloat = 16
        static let heading: CGFloat = 18
        static let section: CGFloat = 22
        static let title: CGFloat = 28
        static let editorial: CGFloat = 32
        static let display: CGFloat = 34
    }
}
struct UFitScaledFont: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var size = UFitTypography.Size.body
    let weight: Font.Weight
    let design: Font.Design
    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight; self.design = design
    }
    func body(content: Content) -> some View { content.font(.system(size: size, weight: weight, design: design)) }
}
extension View {
    func ufitFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(UFitScaledFont(size: size, weight: weight, design: design))
    }
}
