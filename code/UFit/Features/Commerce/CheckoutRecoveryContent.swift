import SwiftUI

struct UFitCheckoutRecoveryContent: View {
    let amount: String?
    let canReplay: Bool
    let isBusy: Bool
    let message: String?
    let onVerify: () -> Void
    let onReplay: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xl) {
            Text(UFitCheckoutRecoveryCopy.title).font(UFitTypography.title2.weight(.semibold))
            Text(UFitCheckoutRecoveryCopy.detail).font(UFitTypography.body).foregroundStyle(Color.ufitSecondaryText)
            if let amount {
                VStack(alignment: .leading, spacing: UFitSpace.sm) {
                    Text(UFitCheckoutRecoveryCopy.amount).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    Text(amount).font(UFitTypography.largeTitle.weight(.medium)).monospacedDigit()
                }.frame(maxWidth: .infinity, alignment: .leading).padding(UFitSpace.lg)
                    .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card))
            }
            if isBusy { UFitLoading(UFitCheckoutRecoveryCopy.loading) }
            else if let message { UFitNotice(message: message, kind: .error) }
            else if canReplay {
                Text(UFitCheckoutRecoveryCopy.absent).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                Text(UFitCheckoutRecoveryCopy.reviewBeforePayment).font(UFitTypography.callout)
            }
            UFitActionButton(title: canReplay ? UFitCheckoutRecoveryCopy.replay : UFitCheckoutRecoveryCopy.verify,
                disabled: isBusy, action: canReplay ? onReplay : onVerify)
        }
    }
}
