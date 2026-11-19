import SwiftUI

struct UFitPaymentDisbursementTargetsView: View {
    let targets: UFitPaymentDisbursementAssessment.Targets
    let context: UFitPaymentAllocationDocument.Context
    let reserved: Bool
    let calculatedAt: UFitTimestamp?
    private typealias Copy = UFitPaymentDisbursementCopy
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
            UFitEditorialHeading(title: reserved ? Copy.reservation : Copy.targets, editorial: false)
            Text(reserved ? Copy.reservationScope : Copy.targetsScope).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            majorShares
            ForEach(context.creatorItems) { item in
                if let line = targets.lines.first(where: { $0.recipient.commissionID == item.commissionId }) {
                    VStack(alignment: .leading, spacing: UFitSpace.sm) {
                        Divider()
                        HStack(alignment: .firstTextBaseline, spacing: UFitSpace.md) {
                            Text(item.creatorName).font(UFitTypography.headline).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: UFitSpace.sm)
                            money(line)
                        }
                        Text(item.itemName).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                    }
                }
            }
            if let calculatedAt { UFitLabeledValue(Copy.latestCalculation, value: Copy.date(calculatedAt)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
            if targets.lines.contains(where: { $0.feeAmount != .zero }) {
                UFitDisclosure(Copy.fee) {
                    VStack(alignment: .leading, spacing: UFitSpace.md) {
                        ForEach(targets.lines.filter { $0.feeAmount != .zero }) { line in
                            UFitLabeledValue(line.recipient.kind == .brand ? context.brand.name : UFitPaymentAllocationCopy.platform,
                                value: UFitMoney.format(line.feeAmount, currency: targets.currency)).font(UFitTypography.callout)
                        }
                    }
                }
            }
        }
    }
    @ViewBuilder private var majorShares: some View {
        if let brand = targets.lines.first(where: { $0.recipient.kind == .brand }),
           let platform = targets.lines.first(where: { $0.recipient.kind == .platform }) {
            ViewThatFits(in: .horizontal) {
                Grid(alignment: .leading, horizontalSpacing: UFitSpace.xl, verticalSpacing: UFitSpace.sm) {
                    GridRow(alignment: .top) { label(context.brand.name); label(UFitPaymentAllocationCopy.platform) }
                    GridRow(alignment: .firstTextBaseline) { money(brand, font: UFitTypography.title2); money(platform, font: UFitTypography.title2) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: UFitSpace.xl) { share(context.brand.name, line: brand); share(UFitPaymentAllocationCopy.platform, line: platform) }
            }
        }
    }
    private func label(_ title: String) -> some View {
        Text(title).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func share(_ title: String, line: UFitPaymentDisbursementAssessment.Targets.Line) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.sm) {
            label(title)
            money(line, font: UFitTypography.title2)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
    private func money(_ line: UFitPaymentDisbursementAssessment.Targets.Line, font: Font = UFitTypography.headline) -> some View {
        Text(UFitMoney.format(line.netAmount, currency: targets.currency)).font(font).monospacedDigit()
            .foregroundStyle(line.netAmount < .zero ? Color.ufitDanger : Color.ufitInk).fixedSize(horizontal: true, vertical: true)
    }
}
