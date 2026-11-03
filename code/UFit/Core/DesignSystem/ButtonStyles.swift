import SwiftUI

enum UFitButtonKind: Equatable { case primary, secondary, tertiary, destructive, text }
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
    private var outlined: Bool { kind == .secondary || kind == .tertiary }
    private var filled: Bool { kind == .primary || kind == .destructive }
    private var ink: Color { kind == .destructive || destructive ? .ufitDanger : .ufitInk }
    private var background: Color {
        switch kind {
        case .primary, .destructive: ink
        case .secondary: inactive || configuration.isPressed ? .ufitSecondary : .ufitCanvas
        case .tertiary: configuration.isPressed ? .ufitBorder : .ufitSecondary
        case .text: .clear
        }
    }
    private var border: Color {
        if inactive { return .ufitBorder }
        if destructive { return .ufitDanger }
        return kind == .secondary ? .ufitActionBorder : .ufitBorder
    }
    var body: some View {
        styledLabel
            .padding(.horizontal, kind == .text ? .zero : compact ? UFitSpace.sm : UFitSpace.lg)
            .padding(.vertical, kind == .text ? .zero : UFitSpace.xs)
            .frame(minWidth: UFitControlSize.touch, minHeight: kind == .text || compact ? UFitControlSize.touch : UFitControlSize.input)
            .background(background, in: RoundedRectangle(cornerRadius: UFitRadius.action))
            .overlay { if outlined { RoundedRectangle(cornerRadius: UFitRadius.action).strokeBorder(border, lineWidth: UFitSpace.hairline) } }
            .opacity(inactive && !outlined ? UFitMotion.disabledOpacity : configuration.isPressed && !outlined ? UFitMotion.pressedOpacity : UFitMotion.visibleOpacity)
            .scaleEffect(configuration.isPressed && !reduceMotion ? UFitMotion.pressedScale : UFitMotion.restingScale)
            .animation(reduceMotion ? nil : .easeOut(duration: UFitMotion.feedback), value: configuration.isPressed)
    }
    @ViewBuilder private var styledLabel: some View {
        if kind == .text { if destructive { configuration.label.foregroundStyle(Color.ufitDanger) } else { configuration.label } }
        else { configuration.label.font(compact ? UFitTypography.subheadline.weight(kind == .tertiary ? .medium : .semibold) : UFitTypography.body.weight(kind == .tertiary ? .medium : .semibold)).foregroundStyle(filled ? Color.ufitCanvas : inactive ? Color.ufitMuted : ink) }
    }
}

private struct UFitButtonKindKey: EnvironmentKey { static let defaultValue = UFitButtonKind.text }
private struct UFitButtonBusyKey: EnvironmentKey { static let defaultValue = false }
private struct UFitCompactButtonKey: EnvironmentKey { static let defaultValue = false }
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
}
extension View {
    func ufitButtonStyle(_ kind: UFitButtonKind, compact: Bool = false) -> some View {
        environment(\.ufitButtonKind, kind).environment(\.ufitCompactButton, compact)
    }
}
