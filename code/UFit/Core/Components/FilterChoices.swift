import SwiftUI

/// A compact value choice stays distinct from an action. Its label defines the context.
struct UFitChoiceChip<Label: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    var body: some View {
        UFitButton(action: action) {
            label().font(selected ? UFitTypography.actionStrong : UFitTypography.action)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, UFitSpace.sm).padding(.vertical, UFitSpace.xs)
                .frame(minHeight: UFitControlSize.touch)
                .foregroundStyle(Color.ufitInk)
                .background(selected ? Color.ufitSecondary : Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.field))
                .overlay { RoundedRectangle(cornerRadius: UFitRadius.field).stroke(selected ? Color.ufitInk : Color.ufitBorder,
                    lineWidth: selected ? UFitStroke.selected : UFitStroke.control) }
        }.ufitButtonStyle(.text).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct UFitFilterChoices<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [UFitSelectionOption<Value>]
    private enum Copy { static var separator: String { " : " } }
    var body: some View {
        FlowLayout(spacing: UFitSpace.xs) {
            ForEach(options) { option in
                UFitChoiceChip(selected: selection == option.value, action: { selection = option.value }) {
                    Text(option.title)
                }.disabled(!option.enabled).accessibilityLabel(title + Copy.separator + option.title)
            }
        }.accessibilityElement(children: .contain)
    }
}
