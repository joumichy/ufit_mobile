import SwiftUI

struct CheckoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var shippingAddress: UFitShippingAddress
    let isCheckingOut: Bool
    let message: String?
    let onCheckout: () -> Void
    private enum Copy {
        static let title = String(localized: "Livraison")
        static let name = String(localized: "Nom complet"); static let address = String(localized: "Adresse")
        static let postal = String(localized: "Code postal"); static let city = String(localized: "Ville"); static let country = String(localized: "Pays")
        static let pay = String(localized: "Payer")
    }
    var body: some View {
        VStack(spacing: UFitSpace.md) {
            UFitSheetHeader(title: Copy.title, onClose: { dismiss() })
            ScrollView {
                VStack(spacing: UFitSpace.md) {
                    UFitTextField(label: Copy.name, text: $shippingAddress.fullName, contentType: .name)
                    UFitTextField(label: Copy.address, text: $shippingAddress.line1, contentType: .streetAddressLine1)
                    UFitTextField(label: Copy.postal, text: $shippingAddress.postalCode, contentType: .postalCode)
                    UFitTextField(label: Copy.city, text: $shippingAddress.city, contentType: .addressCity)
                    UFitTextField(label: Copy.country, text: $shippingAddress.country, contentType: .countryName)
                    if let message { UFitNotice(message: message) }
                    UFitActionButton(title: Copy.pay, isBusy: isCheckingOut, disabled: shippingAddress.fullName.isEmpty || shippingAddress.line1.isEmpty || shippingAddress.postalCode.isEmpty || shippingAddress.city.isEmpty, action: onCheckout)
                }.padding(UFitSpace.page)
            }.scrollDismissesKeyboard(.interactively)
        }.background(Color.ufitCanvas)
    }
}
