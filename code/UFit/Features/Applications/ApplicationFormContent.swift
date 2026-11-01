import SwiftUI

struct UFitApplicationFormContent: View {
    let kind: UFitApplicationKind
    @Binding var values: [UFitApplicationField: String]
    let countries: [UFitCountry]
    let errors: [UFitApplicationField: String]
    let isBusy: Bool
    var isLoadingCountries = false
    let isCorrection: Bool
    let message: String?
    let onBack: () -> Void
    let onSubmit: () -> Void
    var onRetryCountries: (() -> Void)?
    private enum Copy { static let send = String(localized: "Envoyer ma candidature"); static let resubmit = String(localized: "Renvoyer ma candidature"); static let correction = String(localized: "Compléter ma candidature"); static let loadingCountries = String(localized: "Chargement des pays…"); static let retry = String(localized: "Recharger les pays"); static let link = "https://" }
    private enum Layout { static let spacing: CGFloat = 24; static let field: CGFloat = 10; static let radius: CGFloat = 12; static let bottom: CGFloat = 40; static let touch: CGFloat = 44; static let editorHeight: CGFloat = 140; static let title: CGFloat = 30; static let border: CGFloat = 1 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) { if isBusy || isLoadingCountries { ProgressView() } }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    Text(isCorrection ? Copy.correction : kind.title).font(.system(size: Layout.title, design: .serif))
                    if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted) }
                    ForEach(UFitApplicationField.fields(for: kind)) { field in
                        VStack(alignment: .leading, spacing: Layout.field) {
                            Text(field.label(for: kind)).font(.subheadline.weight(.medium))
                            input(field)
                            if let error = errors[field] { Text(error).font(.caption).foregroundStyle(Color.ufitInk).accessibilityLabel(error) }
                        }
                    }
                    Button(action: onSubmit) { Text(isCorrection ? Copy.resubmit : Copy.send).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).disabled(isBusy || isLoadingCountries)
                }.padding(Layout.spacing).padding(.bottom, Layout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).background(Color.white)
    }
    private func binding(_ field: UFitApplicationField) -> Binding<String> { Binding(get: {values[field] ?? String()}, set: {values[field] = $0}) }
    @ViewBuilder private func input(_ field: UFitApplicationField) -> some View {
        Group {
            if field == .country {
                VStack(alignment: .leading) {
                    if countries.isEmpty {
                        if isLoadingCountries { Text(Copy.loadingCountries).frame(minHeight: Layout.touch) }
                        else if let onRetryCountries { Button(Copy.retry, action: onRetryCountries).frame(minHeight: Layout.touch) }
                    } else {
                        Picker(field.label(for: kind), selection: binding(field)) { ForEach(countries) { country in Text(country.name).tag(country.id) } }.labelsHidden().pickerStyle(.menu).tint(Color.ufitInk).frame(minHeight: Layout.touch)
                    }
                }
            } else if field.isMultiline {
                TextEditor(text: binding(field)).frame(minHeight: Layout.editorHeight).scrollContentBackground(.hidden).accessibilityLabel(field.label(for: kind))
            } else {
                TextField(field.isLink ? Copy.link : field.label(for: kind), text: binding(field))
                    .keyboardType(field == .email ? .emailAddress : field.isLink ? .URL : .default)
                    .textInputAutocapitalization(field == .email || field.isLink ? .never : .words)
                    .autocorrectionDisabled(field == .email || field.isLink)
                    .accessibilityLabel(field.label(for: kind))
            }
        }.padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ufitBackground, in: RoundedRectangle(cornerRadius: Layout.radius))
            .overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder, lineWidth: Layout.border) }
            .disabled(isBusy || (field == .country && isLoadingCountries))
    }
}
