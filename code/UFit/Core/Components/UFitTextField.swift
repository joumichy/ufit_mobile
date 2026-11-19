import SwiftUI

struct UFitTextField: View {
    let label: String
    @Binding var text: String
    var error: String?
    var keyboard: UIKeyboardType = .default
    var isIdentifier = false
    var isSecure = false
    var contentType: UITextContentType? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            UFitInput(label, text: $text, error: error, isSecure: isSecure,
                showsLabel: true,
                allowsKeyboardDismissal: [.phonePad, .numberPad, .decimalPad, .asciiCapableNumberPad].contains(keyboard))
                .keyboardType(keyboard).textContentType(contentType)
                .textInputAutocapitalization(isIdentifier ? .never : .sentences).autocorrectionDisabled(isIdentifier)
        }
    }
}
struct UFitInput: View {
    let label: String
    @Binding var text: String
    var error: String?
    var isSecure = false
    var axis: Axis = .horizontal
    let showsLabel: Bool
    let allowsKeyboardDismissal: Bool
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled
    private enum Layout { static let lines = 4...10 }
    private enum Copy { static let dismissKeyboard = String(localized: "Terminer la saisie") }
    private enum Icon { static let dismissKeyboard = "keyboard.chevron.compact.down" }
    init(_ label: String, text: Binding<String>, error: String? = nil, isSecure: Bool = false, axis: Axis = .horizontal,
         showsLabel: Bool = false, allowsKeyboardDismissal: Bool = false) {
        self.label = label; _text = text; self.error = error; self.isSecure = isSecure; self.axis = axis
        self.showsLabel = showsLabel
        self.allowsKeyboardDismissal = allowsKeyboardDismissal
    }
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            if showsLabel || focused && allowsKeyboardDismissal {
                HStack(spacing: UFitSpace.sm) {
                    if showsLabel { Text(label).font(UFitTypography.subheadline.weight(.medium)) }
                    Spacer(minLength: .zero)
                    if focused && allowsKeyboardDismissal {
                        UFitButton { focused = false } label: {
                            UFitIcon(systemName: Icon.dismissKeyboard)
                                .frame(width: UFitControlSize.touch, height: UFitControlSize.touch)
                        }.ufitButtonStyle(.text).accessibilityLabel(Copy.dismissKeyboard)
                    }
                }
            }
            if showsLabel, let error { UFitFieldError(message: error) }
            field
        }
    }
    private var field: some View {
        Group {
            if isSecure { SecureField(label, text: $text) }
            else if axis == .vertical { TextField(label, text: $text, axis: .vertical).lineLimit(Layout.lines) }
            else { TextField(label, text: $text) }
        }.textFieldStyle(.plain).font(UFitTypography.body).foregroundStyle(Color.ufitInk).tint(Color.ufitInk)
            .focused($focused).padding(.horizontal, UFitSpace.md).padding(.vertical, UFitSpace.sm)
            .frame(minHeight: UFitControlSize.input, alignment: .topLeading)
            .background(enabled ? Color.ufitCanvas : Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.field))
            .overlay { RoundedRectangle(cornerRadius: UFitRadius.field).stroke(error != nil ? Color.ufitDanger : focused ? Color.ufitInk : Color.ufitBorder, lineWidth: focused ? UFitStroke.focused : UFitStroke.control) }
            .accessibilityLabel(label).accessibilityHint(error ?? String())
    }
}
struct UFitFieldError: View {
    let message: String
    private enum Icon { static let error = "exclamationmark.circle" }
    var body: some View {
        HStack(alignment: .top, spacing: UFitSpace.xxs) {
            UFitIcon(systemName: Icon.error).accessibilityHidden(true)
            Text(message).fixedSize(horizontal: false, vertical: true)
        }.font(UFitTypography.caption).foregroundStyle(Color.ufitDanger).accessibilityElement(children: .combine)
    }
}
