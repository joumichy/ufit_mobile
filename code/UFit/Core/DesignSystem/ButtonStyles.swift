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
    private var filled: Bool { kind == .primary || kind == .destructive }
    private var ink: Color { kind == .destructive || destructive ? .ufitDanger : .ufitInk }
    private var background: Color {
        switch kind {
        case .primary, .destructive: ink
        case .secondary: .ufitCanvas
        case .tertiary: .ufitSecondary
        case .text: .clear
        }
    }
    var body: some View {
        styledLabel
            .padding(.horizontal, kind == .text ? .zero : compact ? UFitSpace.sm : UFitSpace.lg)
            .padding(.vertical, kind == .text ? .zero : UFitSpace.xs)
            .frame(minWidth: UFitControlSize.touch, minHeight: kind == .text || compact ? UFitControlSize.touch : UFitControlSize.input)
            .background(background, in: RoundedRectangle(cornerRadius: UFitRadius.action))
            .overlay { if kind == .secondary { RoundedRectangle(cornerRadius: UFitRadius.action).stroke(Color.ufitBorder, lineWidth: UFitSpace.hairline) } }
            .opacity(!isEnabled && !isBusy ? UFitMotion.disabledOpacity : configuration.isPressed ? UFitMotion.pressedOpacity : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? UFitMotion.pressedScale : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: UFitMotion.feedback), value: configuration.isPressed)
    }
    @ViewBuilder private var styledLabel: some View {
        if kind == .text { if destructive { configuration.label.foregroundStyle(Color.ufitDanger) } else { configuration.label } }
        else { configuration.label.font(compact ? UFitTypography.subheadline.weight(kind == .tertiary ? .medium : .semibold) : UFitTypography.body.weight(kind == .tertiary ? .medium : .semibold)).foregroundStyle(filled ? Color.ufitCanvas : ink) }
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
