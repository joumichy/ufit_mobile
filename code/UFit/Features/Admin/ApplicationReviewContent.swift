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
    private enum Layout { static let spacing: CGFloat = 24; static let inline: CGFloat = 10; static let title: CGFloat = 30; static let touch: CGFloat = 44; static let radius: CGFloat = 12; static let editorHeight: CGFloat = 140; static let border: CGFloat = 1 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                if isLoading { ProgressView() } else { Button(Copy.refresh, action: onRefresh).frame(minHeight: Layout.touch).disabled(isDeciding) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    Text(Copy.title).font(.system(size: Layout.title, design: .serif))
                    if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted) }
                    if let application {
                        VStack(alignment: .leading, spacing: Layout.inline) {
                            Text(application.name).font(.title2.weight(.medium))
                            Text(application.metadata.type.label + Copy.separator + application.metadata.status.label).font(.subheadline.weight(.semibold))
                            Text(application.metadata.submittedAt.label).font(.caption).foregroundStyle(Color.ufitMuted)
                        }
                        ForEach(UFitApplicationField.fields(for: application.metadata.type)) { field in
                            VStack(alignment: .leading, spacing: Layout.inline) {
                                Text(field.label(for: application.metadata.type)).font(.subheadline.weight(.semibold))
                                if let value = application.formValues[field], !value.isEmpty {
                                    if field.isLink, let url = URL(string: value), url.scheme == Copy.valid { Link(value, destination: url).tint(Color.ufitInk).underline() }
                                    else { Text(value).font(.callout).textSelection(.enabled) }
                                } else { Text(Copy.empty).font(.callout).foregroundStyle(Color.ufitMuted) }
                            }
                        }
                        if let review = application.metadata.latestReview {
                            Divider()
                            VStack(alignment: .leading, spacing: Layout.inline) {
                                Text(Copy.feedback).font(.headline)
                                if let feedback = review.notes { Text(feedback).font(.callout) }
                                Text(review.createdAt.label).font(.caption).foregroundStyle(Color.ufitMuted)
                            }
                        }
                        if application.metadata.status.canReview {
                            Divider()
                            if !application.hasDossier { Text(Copy.missing).font(.callout) }
                            VStack(alignment: .leading, spacing: Layout.inline) {
                                Text(Copy.notes).font(.headline)
                                TextEditor(text: $notes).frame(minHeight: Layout.editorHeight).scrollContentBackground(.hidden).accessibilityLabel(Copy.notes)
                                    .padding().background(Color.ufitBackground, in: RoundedRectangle(cornerRadius: Layout.radius)).overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder, lineWidth: Layout.border) }.disabled(isDeciding)
                                Text(Copy.required).font(.caption).foregroundStyle(Color.ufitMuted)
                            }
                            ForEach(UFitApplicationDecision.allCases) { decision in
                                Button(decision.label) { confirmation = decision }
                                    .frame(maxWidth: .infinity, minHeight: Layout.touch)
                                    .background(decision == .accept ? Color.ufitInk : Color.ufitBackground, in: RoundedRectangle(cornerRadius: Layout.radius))
                                    .foregroundStyle(decision == .accept ? Color.white : Color.ufitInk)
                                    .disabled(!allowsDecision || isLoading || isDeciding || (decision == .accept && !application.hasDossier))
                            }
                            if isDeciding { ProgressView().frame(maxWidth: .infinity) }
                        }
                    }
                }.padding(Layout.spacing).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).background(Color.white)
            .confirmationDialog(confirmation?.label ?? Copy.confirm, isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }), titleVisibility: .visible) {
                if let decision = confirmation { Button(Copy.confirm) { confirmation = nil; onDecide(decision) } }
                Button(Copy.cancel, role: .cancel) { confirmation = nil }
            } message: { Text(Copy.explanation) }
    }
}
