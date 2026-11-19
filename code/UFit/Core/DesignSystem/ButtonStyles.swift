import SwiftUI

enum UFitButtonKind: Equatable { case primary, secondary, tertiary, destructive, text, inversePrimary, inverseSecondary }
struct UFitButtonStyle: ButtonStyle {
    var kind: UFitButtonKind = .primary
    var compact = false
    var destructive = false
    func makeBody(configuration: Configuration) -> some View { UFitButtonVisual(configuration: configuration, kind: kind, compact: compact, destructive: destructive) }
}
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { UFitButtonVisual(configuration: configuration, kind: .primary, compact: false, destructive: false) }
}
struct CompactPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { UFitButtonVisual(configuration: configuration, kind: .primary, compact: true, destructive: false) }
}
private struct UFitButtonVisual: View {
    let configuration: ButtonStyleConfiguration
    let kind: UFitButtonKind
    let compact: Bool
    let destructive: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.ufitButtonIsBusy) private var isBusy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var inactive: Bool { !isEnabled && !isBusy }
    private var inverse: Bool { kind == .inversePrimary || kind == .inverseSecondary }
    private var outlined: Bool { kind == .secondary || kind == .tertiary || kind == .inverseSecondary || inactive && kind != .text }
    private var filled: Bool { kind == .primary || kind == .destructive }
    private var ink: Color { kind == .destructive || destructive ? .ufitDanger : .ufitInk }
    private var background: Color {
        switch kind {
        case .primary, .destructive: inactive ? .ufitSecondary : ink
        case .secondary: inactive || configuration.isPressed ? .ufitSecondary : .ufitCanvas
        case .tertiary: configuration.isPressed ? .ufitBorder : .ufitSecondary
        case .text: .clear
        case .inversePrimary: inactive ? .ufitCanvas.opacity(UFitMotion.disabledOpacity) : .ufitCanvas
        case .inverseSecondary: configuration.isPressed ? .ufitCanvas.opacity(Media.pressedFillOpacity) : .clear
        }
    }
    private var border: Color {
        if inverse { return Color.ufitCanvas.opacity(inactive ? UFitMotion.disabledOpacity : UFitMotion.visibleOpacity) }
        if inactive { return .ufitBorder }
        if kind == .destructive || destructive { return .ufitDanger }
        return kind == .secondary ? .ufitActionBorder : .ufitBorder
    }
    private var labelColor: Color {
        if kind == .inversePrimary { return .ufitInk }
        if kind == .inverseSecondary { return Color.ufitCanvas.opacity(inactive ? UFitMotion.disabledOpacity : UFitMotion.visibleOpacity) }
        return inactive ? .ufitMuted : filled ? .ufitCanvas : ink
    }
    private enum Media { static let pressedFillOpacity = 0.14 }
    var body: some View {
        styledLabel
            .padding(.horizontal, kind == .text ? .zero : compact ? UFitSpace.xs : UFitSpace.md)
            .padding(.vertical, kind == .text ? .zero : UFitSpace.xs)
            .frame(minWidth: UFitControlSize.touch, minHeight: UFitControlSize.action)
            .background(background, in: RoundedRectangle(cornerRadius: UFitRadius.action))
            .overlay { if outlined { RoundedRectangle(cornerRadius: UFitRadius.action).strokeBorder(border, lineWidth: UFitStroke.control) } }
            .frame(minHeight: UFitControlSize.touch)
            .contentShape(Rectangle())
            .opacity(inactive && kind == .text ? UFitMotion.disabledOpacity : configuration.isPressed && !outlined ? UFitMotion.pressedOpacity : UFitMotion.visibleOpacity)
            .animation(reduceMotion ? nil : .easeOut(duration: UFitMotion.feedback), value: configuration.isPressed)
    }
    @ViewBuilder private var styledLabel: some View {
        if kind == .text { if destructive { configuration.label.foregroundStyle(Color.ufitDanger) } else { configuration.label } }
        else { configuration.label.font(kind == .primary || kind == .destructive || kind == .inversePrimary ? UFitTypography.actionStrong : UFitTypography.action).foregroundStyle(labelColor) }
    }
}

private struct UFitButtonKindKey: EnvironmentKey { static let defaultValue = UFitButtonKind.text }
private struct UFitButtonBusyKey: EnvironmentKey { static let defaultValue = false }
private struct UFitCompactButtonKey: EnvironmentKey { static let defaultValue = false }
private struct UFitButtonFillsWidthKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var ufitButtonIsBusy: Bool {
        get { self[UFitButtonBusyKey.self] }
        set { self[UFitButtonBusyKey.self] = newValue }
    }
    var ufitButtonKind: UFitButtonKind {
        get { self[UFitButtonKindKey.self] }
        set { self[UFitButtonKindKey.self] = newValue }
    }
    var ufitCompactButton: Bool {
        get { self[UFitCompactButtonKey.self] }
        set { self[UFitCompactButtonKey.self] = newValue }
    }
    var ufitButtonFillsWidth: Bool {
        get { self[UFitButtonFillsWidthKey.self] }
        set { self[UFitButtonFillsWidthKey.self] = newValue }
    }
}
extension View {
    func ufitButtonStyle(_ kind: UFitButtonKind, compact: Bool = false) -> some View {
        environment(\.ufitButtonKind, kind).environment(\.ufitCompactButton, compact)
    }
}
