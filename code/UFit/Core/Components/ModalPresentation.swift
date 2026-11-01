import SwiftUI

struct UFitSheetHeader: View {
    let title: String
    let onClose: () -> Void
    private enum Icon { static let close = "xmark" }
    var body: some View {
        HStack(spacing: UFitSpace.md) {
            Text(title).font(UFitTypography.title3.weight(.medium)).accessibilityAddTraits(.isHeader)
            Spacer(minLength: UFitSpace.xs)
            UFitButton(action: onClose) { UFitIcon(systemName: Icon.close).font(UFitTypography.body) }
                .ufitButtonStyle(.text).accessibilityLabel(UFitFeedbackCopy.close)
        }.padding(.horizontal, UFitSpace.page).padding(.top, UFitSpace.md)
    }
}
struct UFitDialogContent<Actions: View, Message: View>: View {
    let title: String
    @Binding var isPresented: Bool
    let actions: Actions
    let message: Message
    var body: some View {
        ZStack(alignment: .bottom) {
            UFitSurface.scrim.ignoresSafeArea().onTapGesture { isPresented = false }.accessibilityHidden(true)
            ViewThatFits(in: .vertical) { panel.fixedSize(horizontal: false, vertical: true); ScrollView { panel }.scrollIndicators(.hidden) }
        }.background(Color.clear).presentationBackground(.clear)
    }
    private var panel: some View {
            VStack(alignment: .leading, spacing: UFitSpace.md) {
                UFitSheetHeader(title: title, onClose: { isPresented = false })
                message.font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).padding(.horizontal, UFitSpace.page)
                VStack(spacing: UFitSpace.xs) { actions }
                    .ufitButtonStyle(.secondary)
                    .environment(\.ufitActionDismiss, { isPresented = false })
                    .padding(.horizontal, UFitSpace.page).padding(.bottom, UFitSpace.xl)
            }.background(Color.ufitCanvas, in: UnevenRoundedRectangle(topLeadingRadius: UFitRadius.sheet, topTrailingRadius: UFitRadius.sheet))
                .accessibilityAddTraits(.isModal)
    }
}
private struct UFitSheetPresentation<Panel: View>: ViewModifier {
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    @ViewBuilder let panel: () -> Panel
    @Environment(\.dynamicTypeSize) private var typeSize
    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
            panel().environment(\.dynamicTypeSize, typeSize)
                .presentationDragIndicator(.hidden).presentationCornerRadius(UFitRadius.sheet).presentationBackground(Color.ufitCanvas)
        }
    }
}
private struct UFitItemSheetPresentation<Item: Identifiable, Panel: View>: ViewModifier {
    @Binding var item: Item?
    let onDismiss: (() -> Void)?
    let panel: (Item) -> Panel
    @Environment(\.dynamicTypeSize) private var typeSize
    func body(content: Content) -> some View {
        content.sheet(item: $item, onDismiss: onDismiss) { item in
            panel(item).environment(\.dynamicTypeSize, typeSize)
                .presentationDragIndicator(.hidden).presentationCornerRadius(UFitRadius.sheet).presentationBackground(Color.ufitCanvas)
        }
    }
}
private struct UFitDialogPresentation<Panel: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let panel: () -> Panel
    init(isPresented: Binding<Bool>, @ViewBuilder panel: @escaping () -> Panel) {
        _isPresented = isPresented; self.panel = panel
    }
    @Environment(\.dynamicTypeSize) private var typeSize
    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            panel().environment(\.dynamicTypeSize, typeSize)
        }
    }
}
extension View {
    func ufitSheet<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(UFitSheetPresentation(isPresented: isPresented, onDismiss: onDismiss, panel: content))
    }
    func ufitSheet<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        modifier(UFitItemSheetPresentation(item: item, onDismiss: onDismiss, panel: content))
    }
    func ufitConfirmationDialog<Actions: View, Message: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .visible, @ViewBuilder actions: @escaping () -> Actions, @ViewBuilder message: @escaping () -> Message) -> some View {
        modifier(UFitDialogPresentation(isPresented: isPresented, panel: { UFitDialogContent(title: title, isPresented: isPresented, actions: actions(), message: message()) }))
    }
    func ufitConfirmationDialog<Actions: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .visible, @ViewBuilder actions: @escaping () -> Actions) -> some View {
        ufitConfirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions) { EmptyView() }
    }
    func ufitConfirmationDialog<Data, Actions: View, Message: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .visible, presenting data: Data?, @ViewBuilder actions: @escaping (Data) -> Actions, @ViewBuilder message: @escaping (Data) -> Message) -> some View {
        modifier(UFitDialogPresentation(isPresented: isPresented, panel: {
            if let data { UFitDialogContent(title: title, isPresented: isPresented, actions: actions(data), message: message(data)) }
        }))
    }
    func ufitConfirmationDialog<Data, Actions: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .visible, presenting data: Data?, @ViewBuilder actions: @escaping (Data) -> Actions) -> some View {
        ufitConfirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, presenting: data, actions: actions) { _ in EmptyView() }
    }
}
