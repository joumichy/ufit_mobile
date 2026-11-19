import SwiftUI
import StripePaymentSheet

enum UFitPaymentSheetError: LocalizedError {
    case unavailable
    var errorDescription: String? { String(localized: "Le paiement est momentanément indisponible.") }
}
enum UFitPaymentSheetFactory {
    private enum Configuration {
        static let publicKey = "STRIPE_PUBLIC_KEY"
        static let keyPrefix = "pk_"
        static let merchant = "Ufit"
        static let returnURL = "ufit://payments/return"
        static let applePayMerchantID = "UFIT_APPLE_PAY_MERCHANT_ID"
        static let applePayMerchantCountryCode = "UFIT_APPLE_PAY_MERCHANT_COUNTRY_CODE"
        static let merchantIDPattern = "^merchant\\.[A-Za-z0-9.-]+$"
        static let countryCodePattern = "^[A-Z]{2}$"
        static let unresolvedBuildSetting = "$("
        static let unresolvedEnvironmentSetting = "${"
    }
    static func publicKey() throws -> String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: Configuration.publicKey) as? String, key.hasPrefix(Configuration.keyPrefix) else { throw UFitPaymentSheetError.unavailable }
        return key
    }
    static func make(secret: String, address: UFitShippingAddress, publicKey: String) -> PaymentSheet {
        var configuration = PaymentSheet.Configuration()
        configuration.apiClient = STPAPIClient(publishableKey: publicKey)
        configuration.merchantDisplayName = Configuration.merchant
        configuration.applePay = applePayConfiguration
        configuration.returnURL = Configuration.returnURL
        configuration.style = .alwaysLight
        configuration.link = .init(display: .never)
        configuration.appearance.colors.primary = UIColor(Color.ufitInk)
        configuration.defaultBillingDetails.name = address.fullName
        configuration.defaultBillingDetails.phone = address.phone
        configuration.defaultBillingDetails.address.country = address.country
        configuration.defaultBillingDetails.address.postalCode = address.postalCode
        return PaymentSheet(paymentIntentClientSecret: secret, configuration: configuration)
    }
    private static var applePayConfiguration: PaymentSheet.ApplePayConfiguration? {
        guard let merchantID = configuredValue(for: Configuration.applePayMerchantID),
              let countryCode = configuredValue(for: Configuration.applePayMerchantCountryCode),
              merchantID.range(of: Configuration.merchantIDPattern, options: .regularExpression) != nil,
              countryCode.range(of: Configuration.countryCodePattern, options: .regularExpression) != nil,
              Locale.Region.isoRegions.contains(where: { $0.identifier == countryCode }) else { return nil }
        return .init(merchantId: merchantID, merchantCountryCode: countryCode)
    }
    private static func configuredValue(for key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              !value.contains(Configuration.unresolvedBuildSetting),
              !value.contains(Configuration.unresolvedEnvironmentSetting) else { return nil }
        return value
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
