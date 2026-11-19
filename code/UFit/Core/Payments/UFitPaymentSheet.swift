import SwiftUI
import StripePaymentSheet

enum UFitPaymentSheetError: LocalizedError {
    case unavailable
    var errorDescription: String? { String(localized: "Le paiement est momentanément indisponible.") }
}
enum UFitPaymentSheetFactory {
    private enum Configuration { static let publicKey = "STRIPE_PUBLIC_KEY"; static let keyPrefix = "pk_"; static let merchant = "Ufit"; static let returnURL = "ufit://payments/return" }
    static func publicKey() throws -> String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: Configuration.publicKey) as? String, key.hasPrefix(Configuration.keyPrefix) else { throw UFitPaymentSheetError.unavailable }
        return key
    }
    static func make(secret: String, address: UFitShippingAddress, publicKey: String) -> PaymentSheet {
        var configuration = PaymentSheet.Configuration()
        configuration.apiClient = STPAPIClient(publishableKey: publicKey)
        configuration.merchantDisplayName = Configuration.merchant
        configuration.returnURL = Configuration.returnURL
        configuration.style = .alwaysLight
        configuration.link = .init(display: .never)
        configuration.appearance.colors.primary = UIColor(Color.ufitInk)
        configuration.defaultBillingDetails.name = address.fullName
        configuration.defaultBillingDetails.phone = address.phone
        return PaymentSheet(paymentIntentClientSecret: secret, configuration: configuration)
    }
}
struct UFitStripePaymentPresentation: View {
    let sheet: PaymentSheet
    let onCompletion: (PaymentSheetResult) -> Void
    @State private var isPresented = false
    var body: some View {
        Color.clear.paymentSheet(isPresented: $isPresented, paymentSheet: sheet, onCompletion: onCompletion)
            .onAppear { isPresented = true }
    }
}
