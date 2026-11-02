import SwiftUI

struct UFitDisclosure<Content: View>: View {
    let title: String
    let content: Content
    @State private var expanded = false
    private enum Icon { static var down: String { "chevron.down" }; static var up: String { "chevron.up" } }
    init(_ title: String, initiallyExpanded: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content(); _expanded = State(initialValue: initiallyExpanded)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            UFitButton { expanded.toggle() } label: {
                HStack { Text(title); Spacer(); UFitIcon(systemName: expanded ? Icon.up : Icon.down).font(UFitTypography.caption).accessibilityHidden(true) }.frame(maxWidth: .infinity)
            }.ufitButtonStyle(.text).accessibilityValue(expanded ? Copy.open : Copy.closed)
            if expanded { content }
        }
    }
    private enum Copy { static var open: String { String(localized: "Déplié") }; static var closed: String { String(localized: "Replié") } }
}
struct UFitActionMenu<Content: View>: View {
    let title: String
    let content: Content
    @State private var presented = false
    private enum Icon { static var down: String { "chevron.down" } }
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        UFitButton { presented = true } label: { HStack { Text(title); UFitIcon(systemName: Icon.down).font(UFitTypography.caption) } }
            .ufitButtonStyle(.secondary, compact: true)
            .ufitSheet(isPresented: $presented) {
                VStack(alignment: .leading, spacing: UFitSpace.md) {
                    UFitSheetHeader(title: title, onClose: { presented = false })
                    ScrollView { VStack(alignment: .leading, spacing: UFitSpace.xs) { content }.ufitButtonStyle(.text).environment(\.ufitActionDismiss, { presented = false }).padding(.horizontal, UFitSpace.page) }
                }.background(Color.ufitCanvas)
            }
    }
}
