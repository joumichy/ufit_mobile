import SwiftUI

/// Small, mutually exclusive choices stay visible in the form instead of opening another task.
struct UFitInlineChoice<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [UFitSelectionOption<Value>]
    private enum Copy { static var separator: String { " : " } }
    private enum Layout {
        static var minimumWidth: CGFloat { 128 }
    }
    var body: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: Layout.minimumWidth), spacing: UFitSpace.xs)], spacing: UFitSpace.xs) {
            ForEach(options) { option in
                let selected = option.value == selection
                UFitButton { selection = option.value } label: {
                    Text(option.title).font(selected ? UFitTypography.actionStrong : UFitTypography.action)
                        .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
                        .padding(.horizontal, UFitSpace.xs).padding(.vertical, UFitSpace.xs)
                        .frame(maxWidth: .infinity, minHeight: UFitControlSize.touch)
                        .foregroundStyle(Color.ufitInk)
                        .background(selected ? Color.ufitSecondary : Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.field))
                        .overlay { RoundedRectangle(cornerRadius: UFitRadius.field).stroke(selected ? Color.ufitInk : Color.ufitBorder,
                            lineWidth: selected ? UFitStroke.selected : UFitStroke.control) }
                }.ufitButtonStyle(.text).disabled(!option.enabled)
                    .accessibilityLabel(title + Copy.separator + option.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }.accessibilityElement(children: .contain)
    }
}
