import SwiftUI

private struct UFitActionDismissKey: EnvironmentKey { static let defaultValue: (() -> Void)? = nil }
extension EnvironmentValues {
    var ufitActionDismiss: (() -> Void)? {
        get { self[UFitActionDismissKey.self] }
        set { self[UFitActionDismissKey.self] = newValue }
    }
}
/// Owns the hit target and modal-action lifecycle; the surrounding Ufit style owns the visual variant.
struct UFitButton<Label: View>: View {
    private let role: ButtonRole?
    private let action: () -> Void
    private let label: Label
    @Environment(\.ufitButtonKind) private var kind
    @Environment(\.ufitCompactButton) private var compact
    @Environment(\.ufitActionDismiss) private var dismissAction
    init(role: ButtonRole? = nil, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.role = role; self.action = action; self.label = label()
    }
    var body: some View {
        Button(role: role) { dismissAction?(); action() } label: {
            label.frame(minWidth: kind == .text ? UFitControlSize.touch : .zero, minHeight: kind == .text ? UFitControlSize.touch : .zero).contentShape(Rectangle())
        }.buttonStyle(UFitButtonStyle(kind: kind, compact: compact, destructive: role == .destructive))
    }
}
extension UFitButton where Label == Text {
    init(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) { Text(title) }
    }
}
struct UFitActionButton: View {
    let title: String
    var kind: UFitButtonKind = .primary
    var role: ButtonRole? = nil
    var isBusy = false
    var disabled = false
    let action: () -> Void
    var body: some View {
        UFitButton(role: role, action: action) {
            HStack(spacing: UFitSpace.xs) {
                if isBusy { UFitLoading().foregroundStyle(kind == .primary || kind == .destructive ? Color.ufitCanvas : role == .destructive ? Color.ufitDanger : Color.ufitInk).accessibilityHidden(true) }
                Text(title).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity)
        }.ufitButtonStyle(kind).environment(\.ufitButtonIsBusy, isBusy).disabled(disabled || isBusy)
            .accessibilityValue(isBusy ? UFitFeedbackCopy.loading : String())
    }
}
