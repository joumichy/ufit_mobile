import SwiftUI

struct UFitApplicationReviewContent: View {
    let application: UFitApplicationDocument?
    @Binding var notes: String
    let isLoading: Bool
    let isDeciding: Bool
    var allowsDecision = true
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onDecide: (UFitApplicationDecision) -> Void
    @State private var confirmation: UFitApplicationDecision?
    private enum Copy {
        static let title = String(localized: "Dossier de candidature")
        static let refresh = String(localized: "Actualiser")
        static let missing = String(localized: "Ce dossier doit être complété avant son acceptation.")
        static let notes = String(localized: "Message au candidat")
        static let required = String(localized: "Un message est requis pour un refus, une attente ou une demande de compléments.")
        static let confirm = String(localized: "Confirmer la décision")
        static let cancel = String(localized: "Annuler")
        static let feedback = String(localized: "Dernier retour transmis")
        static let empty = String(localized: "Non renseigné")
        static let explanation = String(localized: "Le candidat verra cette décision et votre message. L’acceptation active son espace Ufit.")
        static let valid = String(localized: "https")
        static let separator = " · "
    }
    private enum Layout { static let spacing: CGFloat = UFitSpace.xl; static let inline: CGFloat = 10; static let title: CGFloat = UFitTypography.Size.editorial; static let touch: CGFloat = UFitControlSize.touch; static let radius: CGFloat = UFitRadius.field; static let editorHeight: CGFloat = 140; static let border: CGFloat = UFitSpace.hairline }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                if isLoading { UFitLoading() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    Text(Copy.title).ufitFont(size: Layout.title, design: .serif).accessibilityAddTraits(.isHeader)
                    if let message {
                        Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        UFitActionButton(title: Copy.refresh, kind: .secondary, disabled: isLoading || isDeciding, action: onRefresh)
                    }
                    if let application {
                        VStack(alignment: .leading, spacing: Layout.inline) {
                            Text(application.name).font(UFitTypography.title2.weight(.medium))
                            Text(application.metadata.type.label + Copy.separator + application.metadata.status.label).font(UFitTypography.subheadline.weight(.semibold))
                            Text(application.metadata.submittedAt.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        }
                        ForEach(UFitApplicationField.fields(for: application.metadata.type)) { field in
                            VStack(alignment: .leading, spacing: Layout.inline) {
                                Text(field.label(for: application.metadata.type)).font(UFitTypography.subheadline.weight(.semibold))
                                if let value = application.formValues[field], !value.isEmpty {
                                    if field.isLink, let url = URL(string: value), url.scheme == Copy.valid { UFitLink(value, destination: url).tint(Color.ufitInk).underline() }
                                    else { Text(value).font(UFitTypography.callout).textSelection(.enabled) }
                                } else { Text(Copy.empty).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                            }
                        }
                        if let review = application.metadata.latestReview {
                            Divider()
                            VStack(alignment: .leading, spacing: Layout.inline) {
                                Text(Copy.feedback).font(UFitTypography.headline)
                                if let feedback = review.notes { Text(feedback).font(UFitTypography.callout) }
                                Text(review.createdAt.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                            }
                        }
                        if application.metadata.status.canReview {
                            Divider()
                            if !application.hasDossier { Text(Copy.missing).font(UFitTypography.callout) }
                            VStack(alignment: .leading, spacing: Layout.inline) {
                                Text(Copy.notes).font(UFitTypography.headline)
                                UFitInput(Copy.notes, text: $notes, axis: .vertical).disabled(isDeciding)
                                Text(Copy.required).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                            }
                            ForEach(UFitApplicationDecision.allCases) { decision in
                                UFitButton(decision.label) { confirmation = decision }
                                    .frame(maxWidth: .infinity, minHeight: Layout.touch)
                                    .ufitButtonStyle(decision == .accept ? .primary : .secondary)
                                    .disabled(!allowsDecision || isLoading || isDeciding || (decision == .accept && !application.hasDossier))
                            }
                            if isDeciding { UFitLoading().frame(maxWidth: .infinity) }
                        }
                    }
                }.padding(Layout.spacing).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
                .ufitRefreshable(isEnabled: !isLoading && !isDeciding, title: Copy.refresh) { onRefresh() }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(confirmation?.label ?? Copy.confirm, isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }), titleVisibility: .visible) {
                if let decision = confirmation { UFitButton(Copy.confirm) { confirmation = nil; onDecide(decision) } }
                UFitButton(Copy.cancel, role: .cancel) { confirmation = nil }
            } message: { Text(Copy.explanation) }
    }
}
