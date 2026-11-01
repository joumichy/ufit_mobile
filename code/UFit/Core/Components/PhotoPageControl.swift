import SwiftUI
import UIKit

struct UFitPhotoPageControl: View {
    let count: Int
    @Binding var selection: Int
    let tint: UIColor
    private enum Drawing { static let dot: CGFloat = 6; static let selected: CGFloat = 18; static let gap: CGFloat = 6; static let inactiveOpacity = 0.40; static let step = 1 }
    private enum Copy {
        static let photos = String(localized: "Photos de la tenue")
        static func page(_ number: Int, count: Int) -> String { String(localized: "Photo \(number) sur \(count)") }
    }
    var body: some View {
        if count > Drawing.step {
            HStack(spacing: Drawing.gap) {
                ForEach(.zero..<count, id: \.self) { index in
                    Capsule().fill(Color(uiColor: tint).opacity(index == selection ? 1 : Drawing.inactiveOpacity))
                        .frame(width: index == selection ? Drawing.selected : Drawing.dot, height: Drawing.dot)
                }
            }.frame(minWidth: UFitControlSize.touch, minHeight: UFitControlSize.touch).contentShape(Rectangle())
                .accessibilityRepresentation { UFitAccessiblePhotoPages(count: count, selection: $selection, label: Copy.photos, value: Copy.page(selection + Drawing.step, count: count)) }.onTapGesture { selection = selection + Drawing.step < count ? selection + Drawing.step : .zero }
        }
    }
}

/// The visible dots are Ufit; UIKit supplies the adjustable-page accessibility contract only.
private struct UFitAccessiblePhotoPages: UIViewRepresentable {
    let count: Int
    @Binding var selection: Int
    let label: String
    let value: String
    func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.accessibilityLabel = label
        control.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return control
    }
    func updateUIView(_ control: UIPageControl, context: Context) {
        context.coordinator.selection = $selection
        control.numberOfPages = count
        control.currentPage = selection
        control.accessibilityValue = value
    }
    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }
    final class Coordinator: NSObject {
        var selection: Binding<Int>
        init(selection: Binding<Int>) { self.selection = selection }
        @objc func changed(_ control: UIPageControl) { selection.wrappedValue = control.currentPage }
    }
}
