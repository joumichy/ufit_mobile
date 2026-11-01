import SwiftUI

struct UFitPhotoPageControl: UIViewRepresentable {
    let count: Int
    @Binding var selection: Int
    let tint: UIColor
    private enum Layout { static let touch: CGFloat = 44; static let inactiveOpacity: CGFloat = 0.35 }
    private enum Copy { static let photos = String(localized: "Photos de la tenue") }
    func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.backgroundStyle = .minimal
        control.hidesForSinglePage = true
        control.accessibilityLabel = Copy.photos
        control.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return control
    }
    func updateUIView(_ control: UIPageControl, context: Context) {
        context.coordinator.selection = $selection
        control.numberOfPages = count
        control.currentPage = selection
        control.currentPageIndicatorTintColor = tint
        control.pageIndicatorTintColor = tint.withAlphaComponent(Layout.inactiveOpacity)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIPageControl, context: Context) -> CGSize? {
        let intrinsic = uiView.size(forNumberOfPages: count)
        return .init(width: max(Layout.touch, intrinsic.width), height: Layout.touch)
    }
    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }
    final class Coordinator: NSObject {
        var selection: Binding<Int>
        init(selection: Binding<Int>) { self.selection = selection }
        @objc func changed(_ control: UIPageControl) { selection.wrappedValue = control.currentPage }
    }
}
