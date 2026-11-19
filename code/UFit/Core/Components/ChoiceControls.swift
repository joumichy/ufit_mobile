import SwiftUI

struct UFitToggle: View {
    let title: String
    @Binding var isOn: Bool
    @Environment(\.isEnabled) private var isEnabled
    private enum Copy { static let yes = String(localized: "Oui"); static let no = String(localized: "Non") }
    private enum Drawing { static let size: CGFloat = 28; static let inset: CGFloat = 6; static let border: CGFloat = 1.5; static let check = "checkmark" }
    init(_ title: String, isOn: Binding<Bool>) { self.title = title; _isOn = isOn }
    var body: some View {
        UFitButton { isOn.toggle() } label: {
            HStack(spacing: UFitSpace.md) {
                Text(title).font(UFitTypography.body).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: UFitSpace.xs)
                ZStack {
                    RoundedRectangle(cornerRadius: UFitRadius.small).fill(isOn ? Color.ufitInk : Color.ufitCanvas)
                    RoundedRectangle(cornerRadius: UFitRadius.small).stroke(isOn ? Color.ufitInk : Color.ufitBorder, lineWidth: Drawing.border)
                    if isOn { UFitIcon(systemName: Drawing.check).font(UFitTypography.caption.weight(.semibold)).foregroundStyle(.white).padding(Drawing.inset) }
                }.frame(width: Drawing.size, height: Drawing.size).accessibilityHidden(true)
            }.frame(maxWidth: .infinity, minHeight: UFitControlSize.touch)
        }.ufitButtonStyle(.text).accessibilityLabel(title).accessibilityValue(isOn ? Copy.yes : Copy.no)
            .accessibilityAddTraits(isOn ? .isSelected : [])
            .accessibilityRepresentation { Toggle(title, isOn: $isOn) }
    }
}
struct UFitQuantityControl<Label: View>: View {
    @Binding var value: Int
    let limits: ClosedRange<Int>
    let step: Int
    let label: Label
    private enum Copy { static var less: String { String(localized: "Diminuer la quantité") }; static var more: String { String(localized: "Augmenter la quantité") }; static var minus: String { "minus" }; static var plus: String { "plus" } }
    init(value: Binding<Int>, in limits: ClosedRange<Int>, step: Int = 1, @ViewBuilder label: () -> Label) {
        _value = value; self.limits = limits; self.step = step; self.label = label()
    }
    var body: some View {
        ViewThatFits(in: .horizontal) { row; VStack(alignment: .leading, spacing: UFitSpace.xs) { label; controls } }
            .font(UFitTypography.body).accessibilityElement(children: .contain)
    }
    private var row: some View { HStack(spacing: UFitSpace.sm) { label; Spacer(minLength: UFitSpace.xs); controls } }
    private var controls: some View {
        HStack(spacing: UFitSpace.xs) {
            UFitButton { value = max(limits.lowerBound, value - step) } label: { UFitIcon(systemName: Copy.minus) }
                .ufitButtonStyle(.secondary, compact: true).disabled(value <= limits.lowerBound).accessibilityLabel(Copy.less)
            Text(value, format: .number).monospacedDigit().frame(minWidth: UFitSpace.xl).accessibilityLabel(String(value))
            UFitButton { value = min(limits.upperBound, value + step) } label: { UFitIcon(systemName: Copy.plus) }
                .ufitButtonStyle(.secondary, compact: true).disabled(value >= limits.upperBound).accessibilityLabel(Copy.more)
        }
    }
}
extension UFitQuantityControl where Label == Text {
    init(_ title: String, value: Binding<Int>, in limits: ClosedRange<Int>, step: Int = 1) {
        self.init(value: value, in: limits, step: step) { Text(title) }
    }
}

struct UFitSlider: View {
    @Binding var value: Double
    let limits: ClosedRange<Double>
    let step: Double
    @Environment(\.isEnabled) private var enabled
    private enum Drawing { static let track: CGFloat = 3; static let thumb: CGFloat = 24; static let half: CGFloat = 2 }
    init(value: Binding<Double>, in limits: ClosedRange<Double>, step: Double) { _value = value; self.limits = limits; self.step = step }
    private var fraction: Double { (value - limits.lowerBound) / max(step, limits.upperBound - limits.lowerBound) }
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.ufitBorder).frame(height: Drawing.track)
                Capsule().fill(Color.ufitInk).frame(width: max(.zero, proxy.size.width * fraction), height: Drawing.track)
                Circle().fill(Color.ufitInk).frame(width: Drawing.thumb, height: Drawing.thumb)
                    .offset(x: max(.zero, min(proxy.size.width - Drawing.thumb, proxy.size.width * fraction - Drawing.thumb / Drawing.half)))
            }.frame(height: UFitControlSize.touch).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: .zero).onChanged { gesture in
                    guard enabled else { return }
                    let proposed = limits.lowerBound + Double(gesture.location.x / max(UFitSpace.hairline, proxy.size.width)) * (limits.upperBound - limits.lowerBound)
                    value = min(limits.upperBound, max(limits.lowerBound, (proposed / step).rounded() * step))
                })
        }.frame(height: UFitControlSize.touch)
            .accessibilityRepresentation {
                Slider(value: $value, in: limits, step: step)
                    .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(.zero))))
            }.opacity(enabled ? 1 : UFitMotion.disabledOpacity)
    }
}
