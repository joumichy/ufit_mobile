import SwiftUI
import UIKit

/// Ufit owns the composition and styling; UIKit supplies text editing and the system keyboard.
struct UFitTimeEntry: View {
    @Binding var hours: String
    @Binding var minutes: String
    @State private var focused: Part?
    @ScaledMetric(relativeTo: .largeTitle) private var digitSize = Layout.digitSize
    @Environment(\.isEnabled) private var isEnabled
    private enum Part { case hours, minutes }
    private enum Copy {
        static let hours = String(localized: "Heures")
        static let minutes = String(localized: "Minutes")
        static let done = String(localized: "Terminer la saisie")
        static let separator = ":"
    }
    private enum Layout {
        static let digitSize: CGFloat = 52
        static let underline: CGFloat = 2
        static let fullOpacity = 1.0
    }
    var body: some View {
        VStack(spacing: UFitSpace.md) {
            HStack(alignment: .center, spacing: UFitSpace.sm) {
                number(.hours, title: Copy.hours, value: $hours, upperBound: UFitPublicationCalendarMath.hourCount)
                Text(Copy.separator).ufitFont(size: digitSize, weight: .light).padding(.top, UFitSpace.lg).accessibilityHidden(true)
                number(.minutes, title: Copy.minutes, value: $minutes, upperBound: UFitPublicationCalendarMath.minuteCount)
            }
            if focused != nil {
                HStack {
                    Spacer(minLength: UFitSpace.sm)
                    UFitButton(Copy.done) { focused = nil }.ufitButtonStyle(.text)
                        .font(UFitTypography.caption.weight(.semibold))
                }.frame(minHeight: UFitControlSize.touch)
            }
        }.opacity(isEnabled ? Layout.fullOpacity : UFitMotion.disabledOpacity)
    }
    private func number(_ part: Part, title: String, value: Binding<String>, upperBound: Int) -> some View {
        VStack(spacing: UFitSpace.xs) {
            Text(title).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            UFitTimeDigits(title: title, text: value, size: digitSize, isEnabled: isEnabled,
                isFocused: focused == part, isLast: part == .minutes,
                onFocus: { if focused != part { focused = part } }, onEnd: {
                    if let number = UFitPublicationCalendarMath.timeValue(value.wrappedValue, upperBound: upperBound),
                       value.wrappedValue != UFitPublicationCalendarMath.minuteLabel(number) {
                        value.wrappedValue = UFitPublicationCalendarMath.minuteLabel(number)
                    }
                    if focused == part { focused = nil }
                }, onComplete: { focused = part == .hours ? .minutes : nil })
                .overlay(alignment: .bottom) {
                    Rectangle().fill(focused == part ? Color.ufitInk : Color.ufitBorder).frame(height: Layout.underline)
                }
        }.frame(maxWidth: .infinity)
    }
}

private struct UFitTimeDigits: UIViewRepresentable {
    let title: String
    @Binding var text: String
    let size: CGFloat
    let isEnabled: Bool
    let isFocused: Bool
    let isLast: Bool
    let onFocus: () -> Void
    let onEnd: () -> Void
    let onComplete: () -> Void
    private enum Value { static let placeholder = "00" }
    func makeCoordinator() -> Coordinator { Coordinator(input: self) }
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textAlignment = .center
        field.textColor = UIColor(Color.ufitInk)
        field.tintColor = UIColor(Color.ufitInk)
        field.keyboardType = .numberPad
        field.keyboardAppearance = .light
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.placeholder = Value.placeholder
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }
    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.input = self
        if field.text != text { field.text = text }
        field.font = .monospacedDigitSystemFont(ofSize: size, weight: .medium)
        field.accessibilityLabel = title
        field.isEnabled = isEnabled
        field.returnKeyType = isLast ? .done : .next
        if isFocused && !field.isFirstResponder { field.becomeFirstResponder() }
        else if !isFocused && field.isFirstResponder { field.resignFirstResponder() }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        .init(width: proposal.width ?? uiView.intrinsicContentSize.width,
              height: max(UFitControlSize.input, uiView.intrinsicContentSize.height + UFitSpace.sm))
    }
    final class Coordinator: NSObject, UITextFieldDelegate {
        var input: UFitTimeDigits
        init(input: UFitTimeDigits) { self.input = input }
        @objc func changed(_ field: UITextField) { input.text = field.text ?? String() }
        func textFieldDidBeginEditing(_ field: UITextField) {
            input.onFocus()
            // UIKit places its caret after the delegate call; replace the existing value on the next turn.
            DispatchQueue.main.async { if field.isFirstResponder { field.selectAll(nil) } }
        }
        func textFieldDidEndEditing(_ field: UITextField) {
            let onEnd = input.onEnd
            DispatchQueue.main.async { onEnd() }
        }
        func textFieldShouldReturn(_ field: UITextField) -> Bool { input.onComplete(); return false }
    }
}
