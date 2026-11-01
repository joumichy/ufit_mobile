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
    private enum Layout { static let spacing: CGFloat = UFitSpace.xl; static let field: CGFloat = 10; static let radius: CGFloat = UFitRadius.field; static let bottom: CGFloat = 40; static let touch: CGFloat = UFitControlSize.touch; static let editorHeight: CGFloat = 140; static let title: CGFloat = UFitTypography.Size.editorial; static let border: CGFloat = UFitSpace.hairline }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) { if isBusy || isLoadingCountries { UFitLoading() } }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    Text(isCorrection ? Copy.correction : kind.title).ufitFont(size: Layout.title, design: .serif)
                    if let message { Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                    ForEach(UFitApplicationField.fields(for: kind)) { field in
                        VStack(alignment: .leading, spacing: Layout.field) {
                            Text(field.label(for: kind)).font(UFitTypography.subheadline.weight(.medium))
                            input(field)
                            if let error = errors[field] { UFitFieldError(message: error) }
                        }
                    }
                    UFitButton(action: onSubmit) { Text(isCorrection ? Copy.resubmit : Copy.send).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).disabled(isBusy || isLoadingCountries)
                }.padding(Layout.spacing).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func binding(_ field: UFitApplicationField) -> Binding<String> { Binding(get: {values[field] ?? String()}, set: {values[field] = $0}) }
    @ViewBuilder private func input(_ field: UFitApplicationField) -> some View {
        Group {
            if field == .country {
                VStack(alignment: .leading) {
                    if countries.isEmpty {
                        if isLoadingCountries { Text(Copy.loadingCountries).frame(minHeight: Layout.touch) }
                        else if let onRetryCountries { UFitButton(Copy.retry, action: onRetryCountries).frame(minHeight: Layout.touch) }
                    } else {
                        UFitSelection(field.label(for: kind), selection: binding(field), options: countries.map { .init(value: $0.id, title: $0.name) }).tint(Color.ufitInk).frame(minHeight: Layout.touch)
                    }
                }
            } else if field.isMultiline {
                UFitInput(field.label(for: kind), text: binding(field), error: errors[field], axis: .vertical).frame(minHeight: Layout.editorHeight).accessibilityLabel(field.label(for: kind))
            } else {
                UFitInput(field.isLink ? Copy.link : field.label(for: kind), text: binding(field), error: errors[field])
                    .keyboardType(field == .email ? .emailAddress : field.isLink ? .URL : .default)
                    .textInputAutocapitalization(field == .email || field.isLink ? .never : .words)
                    .autocorrectionDisabled(field == .email || field.isLink)
                    .accessibilityLabel(field.label(for: kind))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .disabled(isBusy || (field == .country && isLoadingCountries))
    }
}
