import SwiftUI

struct UFitRevenueChartPoint: Identifiable {
    let id: String
    let label: String
    let value: Int
    let formatted: String
}
/// A Ufit-owned, zero-based revenue plot. Every value remains available without a gesture.
struct UFitRevenueChart: View {
    let points: [UFitRevenueChartPoint]
    let title: String
    @State private var selectedID: String?
    @State private var showsValues = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private enum Layout {
        static let height: CGFloat = 152
        static let line: CGFloat = 2
        static let marker: CGFloat = 7
        static let padding: CGFloat = 5
        static let guideCount = 3
        static let divisions: CGFloat = 2
        static let axisLine: CGFloat = 1
        static let guideDash: [CGFloat] = [3, 4]
        static let cursorOpacity = 0.4
        static let step = 1
        static let accessibilityHeightDivisor: CGFloat = 2
    }
    private enum Icon { static let chart = "chart.xyaxis.line"; static let table = "tablecells"; static let expand = "chevron.down"; static let collapse = "chevron.up" }
    private var selectedIndex: Int? { points.firstIndex { $0.id == selectedID } }
    private var maximum: Int { points.map(\.value).max() ?? .zero }
    private var selected: UFitRevenueChartPoint? { selectedIndex.map { points[$0] } }
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.sm) {
            if let maximumPoint = points.max(by: { $0.value < $1.value }) {
                Text(String(localized: "Échelle : 0 – \(maximumPoint.formatted)"))
                    .font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText)
            }
            if let selected {
                HStack(alignment: .firstTextBaseline) {
                    Text(selected.label).foregroundStyle(Color.ufitSecondaryText)
                    Spacer()
                    Text(selected.formatted).monospacedDigit()
                }.font(UFitTypography.caption).accessibilityElement(children: .combine)
            }
            GeometryReader { geometry in
                let size = geometry.size
                let height = size.height - Layout.padding * 2
                let width = size.width - Layout.padding * 2
                ZStack(alignment: .topLeading) {
                    ForEach(0..<Layout.guideCount) { index in
                        Path { path in
                            let y = Layout.padding + height * CGFloat(index) / Layout.divisions
                            path.move(to: CGPoint(x: .zero, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                        }.stroke(Color.ufitBorder, style: StrokeStyle(lineWidth: Layout.axisLine, dash: index == Layout.guideCount - Layout.step ? [] : Layout.guideDash))
                    }
                    Path { path in
                        for (index, point) in points.enumerated() {
                            let location = location(index, point.value, width: width, height: height)
                            if index == .zero { path.move(to: location) } else { path.addLine(to: location) }
                        }
                    }.stroke(Color.ufitInk, style: StrokeStyle(lineWidth: Layout.line, lineCap: .round, lineJoin: .round))
                    if let index = selectedIndex {
                        let position = location(index, points[index].value, width: width, height: height)
                        Path { path in
                            path.move(to: CGPoint(x: position.x, y: Layout.padding))
                            path.addLine(to: CGPoint(x: position.x, y: size.height - Layout.padding))
                        }.stroke(Color.ufitSecondaryText.opacity(Layout.cursorOpacity), style: StrokeStyle(lineWidth: Layout.axisLine, dash: Layout.guideDash))
                        Circle().fill(Color.ufitInk).frame(width: Layout.marker, height: Layout.marker)
                            .position(position)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    guard !points.isEmpty, width > .zero else { return }
                    let position = (location.x - Layout.padding) / width
                    let index = max(.zero, min(points.count - Layout.step, Int((position * CGFloat(points.count - Layout.step)).rounded())))
                    selectedID = points[index].id
                }
            }
            .frame(height: dynamicTypeSize.isAccessibilitySize ? Layout.height / Layout.accessibilityHeightDivisor : Layout.height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(selected.map { "\($0.label), \($0.formatted)" } ?? String(localized: "Sélectionnez une période du graphique"))
            .accessibilityAdjustableAction { direction in
                guard !points.isEmpty else { return }
                let index = selectedIndex ?? .zero
                switch direction {
                case .increment: selectedID = points[min(points.count - Layout.step, index + Layout.step)].id
                case .decrement: selectedID = points[max(.zero, index - Layout.step)].id
                @unknown default: break
                }
            }
            HStack {
                if let first = points.first { Text(first.label) }
                Spacer()
                if let last = points.last { Text(last.label) }
            }.font(UFitTypography.caption2).foregroundStyle(Color.ufitSecondaryText).accessibilityHidden(true)
            UFitButton(action: { showsValues.toggle() }) {
                HStack(spacing: UFitSpace.xs) {
                    UFitIcon(systemName: showsValues ? Icon.chart : Icon.table)
                    Text(showsValues ? String(localized: "Masquer les valeurs") : String(localized: "Voir les valeurs"))
                    Spacer()
                    UFitIcon(systemName: showsValues ? Icon.collapse : Icon.expand)
                }.font(UFitTypography.caption)
            }.ufitButtonStyle(.secondary, compact: true)
            if showsValues {
                VStack(spacing: UFitSpace.sm) {
                    ForEach(points) { point in
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline) { Text(point.label); Spacer(); Text(point.formatted).monospacedDigit() }
                            VStack(alignment: .leading) { Text(point.label); Text(point.formatted).monospacedDigit() }
                        }.font(UFitTypography.caption).accessibilityElement(children: .combine)
                    }
                }.padding(.top, UFitSpace.sm)
            }
        }
        .onChange(of: points.map(\.id), initial: true) { _, _ in selectedID = points.last(where: { $0.value > .zero })?.id ?? points.last?.id }
    }
    private func location(_ index: Int, _ value: Int, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: Layout.padding + width * CGFloat(index) / CGFloat(max(Layout.step, points.count - Layout.step)),
                y: Layout.padding + height * (CGFloat(Layout.step) - (maximum > .zero ? CGFloat(value) / CGFloat(maximum) : .zero)))
    }
}
