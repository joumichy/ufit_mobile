import SwiftUI

struct UFitMultilineField: View {
    let label: String
    @Binding var text: String
    var error: String?
    var isIdentifier = false
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            Text(label).font(UFitTypography.subheadline.weight(.medium))
            UFitInput(label, text: $text, error: error, axis: .vertical).textInputAutocapitalization(isIdentifier ? .never : .sentences).autocorrectionDisabled(isIdentifier)
            if let error { UFitFieldError(message: error) }
        }
    }
}
