import SwiftUI

struct UFitCustomerPaymentStatusContent: View {
    let payment: UFitCustomerPaymentStatusDTO?
    let isLoading: Bool
    let message: String?
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            if isLoading && payment == nil {
                UFitLoading(UFitCustomerPaymentCopy.loading)
            } else if let message {
                UFitNotice(message: message, kind: .error)
            } else if let payment {
                Text(UFitCustomerPaymentCopy.title(payment.state)).font(UFitTypography.headline)
                Text(UFitCustomerPaymentCopy.detail(payment.state)).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(UFitSpace.lg)
            .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card))
    }
}
