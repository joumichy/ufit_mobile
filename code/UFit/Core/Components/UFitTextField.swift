import SwiftUI

struct UFitTextField: View {
    let label: String
    @Binding var text: String
    var error: String?
    var keyboard: UIKeyboardType = .default
    var isIdentifier = false
    private enum Layout { static let gap: CGFloat = 8; static let inset: CGFloat = 16; static let height: CGFloat = 48; static let radius: CGFloat = 12 }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(label).font(.subheadline.weight(.medium))
            TextField(label, text: $text).keyboardType(keyboard)
                .textInputAutocapitalization(isIdentifier ? .never : .sentences).autocorrectionDisabled(isIdentifier)
                .padding(.horizontal, Layout.inset).frame(minHeight: Layout.height)
                .overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }.accessibilityLabel(label)
            if let error { Text(error).font(.caption) }
        }
    }
}
