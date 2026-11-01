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
            Text(label).font(UFitTypography.subheadline.weight(.medium))
            UFitInput(label, text: $text, error: error, isSecure: isSecure)
                .keyboardType(keyboard).textContentType(contentType)
                .textInputAutocapitalization(isIdentifier ? .never : .sentences).autocorrectionDisabled(isIdentifier)
            if let error { UFitFieldError(message: error) }
        }
    }
}
struct UFitInput: View {
    let label: String
    @Binding var text: String
    var error: String?
    var isSecure = false
    var axis: Axis = .horizontal
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled
    private enum Layout { static let focusedBorder: CGFloat = 2; static let lines = 4...10 }
    init(_ label: String, text: Binding<String>, error: String? = nil, isSecure: Bool = false, axis: Axis = .horizontal) {
        self.label = label; _text = text; self.error = error; self.isSecure = isSecure; self.axis = axis
    }
    var body: some View {
        Group {
            if isSecure { SecureField(label, text: $text) }
            else if axis == .vertical { TextField(label, text: $text, axis: .vertical).lineLimit(Layout.lines) }
            else { TextField(label, text: $text) }
        }.textFieldStyle(.plain).font(UFitTypography.body).foregroundStyle(Color.ufitInk).tint(Color.ufitInk)
            .focused($focused).padding(.horizontal, UFitSpace.md).padding(.vertical, UFitSpace.sm)
            .frame(minHeight: UFitControlSize.input, alignment: .topLeading)
            .background(enabled ? Color.ufitCanvas : Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.field))
            .overlay { RoundedRectangle(cornerRadius: UFitRadius.field).stroke(error != nil ? Color.ufitDanger : focused ? Color.ufitInk : Color.ufitBorder, lineWidth: focused ? Layout.focusedBorder : UFitSpace.hairline) }
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
