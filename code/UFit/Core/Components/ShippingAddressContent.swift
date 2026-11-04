import SwiftUI

struct UFitShippingAddressFields: View {
    @Binding var address: UFitShippingAddress
    let countries: [UFitCountry]
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            UFitTextField(label: String(localized: "Nom complet"), text: $address.fullName, contentType: .name)
            UFitTextField(label: String(localized: "Adresse"), text: $address.line1, contentType: .streetAddressLine1)
            UFitTextField(label: String(localized: "Complément d’adresse (facultatif)"), text: optional($address.line2), contentType: .streetAddressLine2)
            HStack(alignment: .top, spacing: UFitSpace.md) {
                UFitTextField(label: String(localized: "Code postal"), text: $address.postalCode, contentType: .postalCode)
                UFitTextField(label: String(localized: "Ville"), text: $address.city, contentType: .addressCity)
            }
            HStack {
                Text(String(localized: "Pays")).font(UFitTypography.subheadline.weight(.medium))
                Spacer()
                if countries.isEmpty {
                    Text(UFitCountry.displayLocale.localizedString(forRegionCode: address.country) ?? address.country)
                        .foregroundStyle(Color.ufitSecondaryText)
                } else {
                    UFitSelection(String(localized: "Pays de livraison"), selection: $address.country,
                        options: countries.map { .init(value: $0.id, title: $0.name) })
                }
            }.frame(minHeight: UFitControlSize.input)
            UFitTextField(label: String(localized: "Téléphone (facultatif)"), text: optional($address.phone),
                keyboard: .phonePad, contentType: .telephoneNumber)
        }.autocorrectionDisabled()
    }
    private func optional(_ value: Binding<String?>) -> Binding<String> {
        Binding(get: { value.wrappedValue ?? String() }, set: { value.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}

struct UFitPostalAddress: View {
    let address: UFitShippingAddress
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xxs) {
            Text(address.fullName).font(UFitTypography.headline)
            Text(address.line1)
            if let line2 = address.line2, !line2.isEmpty { Text(line2) }
            Text(address.postalCode + " " + address.city)
            Text(UFitCountry.displayLocale.localizedString(forRegionCode: address.country) ?? address.country)
            if let phone = address.phone, !phone.isEmpty { Text(phone).foregroundStyle(Color.ufitSecondaryText) }
        }.font(UFitTypography.subheadline).accessibilityElement(children: .combine)
    }
}
