import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = UFitSpace.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrangement(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let item = layout.items[index]
            subview.place(at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                proposal: ProposedViewSize(item.size))
        }
    }

    private func arrangement(width: CGFloat?, subviews: Subviews) -> (size: CGSize, items: [CGRect]) {
        let proposedWidth = width.flatMap { $0.isFinite ? max(.zero, $0) : nil }
        let available = proposedWidth ?? .infinity
        let bounded = ProposedViewSize(width: available.isFinite ? available : nil, height: nil)
        var items = [CGRect]()
        var point = CGPoint.zero
        var rowHeight: CGFloat = .zero
        var usedWidth: CGFloat = .zero
        for subview in subviews {
            let ideal = subview.sizeThatFits(.unspecified)
            let measured = ideal.width > available ? subview.sizeThatFits(bounded) : ideal
            let size = CGSize(width: min(measured.width, available), height: measured.height)
            if point.x > .zero && point.x + size.width > available {
                point.x = .zero
                point.y += rowHeight + spacing
                rowHeight = .zero
            }
            items.append(CGRect(origin: point, size: size))
            usedWidth = max(usedWidth, point.x + size.width)
            point.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: proposedWidth ?? usedWidth, height: point.y + rowHeight), items)
    }
}
