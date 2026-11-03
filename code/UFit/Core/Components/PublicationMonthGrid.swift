import SwiftUI

/// Calendar appearance owned by Ufit; the system calendar is used only for date arithmetic.
struct UFitPublicationMonthGrid: View {
    let month: Date
    let selectedDay: Date
    let timeZone: TimeZone
    var markedDays: Set<Int> = []
    var isEnabled = true
    let onMoveMonth: (Int) -> Void
    let onSelectDay: (Date) -> Void
    private enum Value { static let columns = 7; static let first = 1; static let previous = -1; static let next = 1; static let monday = 2 }
    private enum Copy {
        static let previous = String(localized: "Mois précédent")
        static let next = String(localized: "Mois suivant")
        static let publication = String(localized: "Publication")
    }
    private enum Icon { static let previous = "chevron.left"; static let next = "chevron.right" }
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = UFitPublicationFormatting.locale; value.timeZone = timeZone; value.firstWeekday = Value.monday
        return value
    }
    private var monthStart: Date { calendar.dateInterval(of: .month, for: month)!.start }
    private var offset: Int { (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + Value.columns) % Value.columns }
    private var days: Range<Int> { calendar.range(of: .day, in: .month, for: month)! }
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: UFitSpace.xs), count: Value.columns) }
    var body: some View {
        VStack(spacing: UFitSpace.sm) {
            HStack {
                UFitButton { onMoveMonth(Value.previous) } label: { UFitIcon(systemName: Icon.previous).frame(width: UFitControlSize.touch, height: UFitControlSize.touch) }
                    .accessibilityLabel(Copy.previous)
                Spacer(minLength: .zero)
                Text(UFitPublicationFormatting.text(monthStart, template: .month, zone: timeZone))
                    .font(UFitTypography.headline).accessibilityAddTraits(.isHeader)
                Spacer(minLength: .zero)
                UFitButton { onMoveMonth(Value.next) } label: { UFitIcon(systemName: Icon.next).frame(width: UFitControlSize.touch, height: UFitControlSize.touch) }
                    .accessibilityLabel(Copy.next)
            }
            LazyVGrid(columns: columns, spacing: UFitSpace.xs) {
                ForEach(.zero..<Value.columns, id: \.self) { index in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - Value.first + index) % Value.columns])
                        .font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText).accessibilityHidden(true)
                }
                ForEach(.zero..<(offset + days.count), id: \.self) { cell in
                    if cell < offset { Color.clear.frame(minHeight: UFitControlSize.touch).accessibilityHidden(true) }
                    else { day(cell - offset + Value.first) }
                }
            }
        }.disabled(!isEnabled)
    }
    private func day(_ number: Int) -> some View {
        let date = calendar.date(byAdding: .day, value: number - Value.first, to: monthStart)!
        let selected = calendar.isDate(date, inSameDayAs: selectedDay)
        return UFitButton { onSelectDay(date) } label: {
            VStack(spacing: UFitSpace.xs) {
                Text(number.formatted()).font(UFitTypography.callout)
                Circle().fill(markedDays.contains(number) ? (selected ? Color.ufitCanvas : Color.ufitInk) : Color.clear)
                    .frame(width: UFitSpace.xs, height: UFitSpace.xs)
            }.frame(maxWidth: .infinity, minHeight: UFitControlSize.touch)
                .foregroundStyle(selected ? Color.ufitCanvas : Color.ufitInk)
                .background(selected ? Color.ufitInk : Color.clear, in: RoundedRectangle(cornerRadius: UFitRadius.field))
        }.ufitButtonStyle(.text)
            .accessibilityLabel(UFitPublicationFormatting.text(date, template: .day, zone: timeZone))
            .accessibilityValue(markedDays.contains(number) ? Copy.publication : String())
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
