import SwiftUI

struct UFitOutfitItemIcon: View {
    let symbol: String
    private enum Layout {
        static let size: CGFloat = 23; static let stroke: CGFloat = 1.5
        static let waistLeft: CGFloat = 0.28; static let waistRight: CGFloat = 0.72; static let waistTop: CGFloat = 0.1
        static let hemLeft: CGFloat = 0.13; static let hemRight: CGFloat = 0.87; static let hemTop: CGFloat = 0.9
        static let innerLeft: CGFloat = 0.4; static let innerRight: CGFloat = 0.6; static let crotch: CGFloat = 0.42; static let middle: CGFloat = 0.5
    }
    var body: some View {
        Group {
            if symbol == UFitOutfitItemType.bottom.symbol {
                GeometryReader { proxy in
                    Path { path in
                        let width = proxy.size.width, height = proxy.size.height
                        path.move(to: .init(x: width * Layout.waistLeft, y: height * Layout.waistTop))
                        path.addLine(to: .init(x: width * Layout.waistRight, y: height * Layout.waistTop))
                        path.addLine(to: .init(x: width * Layout.hemRight, y: height * Layout.hemTop))
                        path.addLine(to: .init(x: width * Layout.innerRight, y: height * Layout.hemTop))
                        path.addLine(to: .init(x: width * Layout.middle, y: height * Layout.crotch))
                        path.addLine(to: .init(x: width * Layout.innerLeft, y: height * Layout.hemTop))
                        path.addLine(to: .init(x: width * Layout.hemLeft, y: height * Layout.hemTop))
                        path.closeSubpath()
                    }.stroke(style: StrokeStyle(lineWidth: Layout.stroke, lineCap: .round, lineJoin: .round))
                }
            } else { Image(systemName: symbol).font(.system(size: Layout.size, weight: .regular)) }
        }.frame(width: Layout.size, height: Layout.size)
    }
}
