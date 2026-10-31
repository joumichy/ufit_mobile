import SwiftUI

struct CheckoutSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var shippingAddress: UFitShippingAddress
    let isCheckingOut: Bool
    let message: String?
    let onCheckout: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Shipping") {
                    TextField("Full name", text: $shippingAddress.fullName)
                    TextField("Address", text: $shippingAddress.line1)
                    TextField("Postal code", text: $shippingAddress.postalCode)
                    TextField("City", text: $shippingAddress.city)
                    TextField("Country", text: $shippingAddress.country)
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.ufitMuted)
                    }
                }
            }
            .navigationTitle("Checkout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCheckingOut ? "Preparing..." : "Pay") {
                        onCheckout()
                    }
                    .disabled(isCheckingOut || shippingAddress.fullName.isEmpty || shippingAddress.line1.isEmpty || shippingAddress.postalCode.isEmpty || shippingAddress.city.isEmpty)
                }
            }
        }
    }
}
