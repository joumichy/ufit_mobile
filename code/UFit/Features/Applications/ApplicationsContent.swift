import SwiftUI

struct UFitApplicationsContent: View {
    let creator: UFitApplicationDocument?
    let brand: UFitApplicationDocument?
    let canApplyCreator: Bool
    let canApplyBrand: Bool
    let hasLoaded: Bool
    let isLoading: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onApply: (UFitApplicationKind) -> Void
    let onCorrect: (UFitApplicationDocument) -> Void
    let onPayments: () -> Void
    private enum Copy {
        static let title = String(localized: "Mes candidatures")
        static let refresh = String(localized: "Actualiser")
        static let correct = String(localized: "Compléter ma candidature")
        static let feedback = String(localized: "Dernier retour de l’équipe")
        static let submitted = String(localized: "Envoyée le")
        static let payments = String(localized: "Paiements et versements")
        static let anotherBrand = String(localized: "Proposer une autre marque")
        static let newCreator = String(localized: "Présentez votre univers et trois tenues.")
        static let newBrand = String(localized: "Présentez votre marque et ses possibilités de vente.")
    }
    private enum Layout { static let spacing: CGFloat = 24; static let inline: CGFloat = 12; static let radius: CGFloat = 16; static let bottom: CGFloat = 110; static let title: CGFloat = 32; static let touch: CGFloat = 44 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) { if isLoading { ProgressView().frame(minWidth: Layout.touch, minHeight: Layout.touch) } else { Button(Copy.refresh, action: onRefresh).frame(minHeight: Layout.touch) } }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    Text(Copy.title).font(.system(size: Layout.title, design: .serif))
                    if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted) }
                    if hasLoaded {
                        card(.creator, creator, canApply: canApplyCreator)
                        card(.brand, brand, canApply: canApplyBrand)
                    }
                }.padding(Layout.spacing).padding(.bottom, Layout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).background(Color.white)
    }
    private func card(_ kind: UFitApplicationKind, _ application: UFitApplicationDocument?, canApply: Bool) -> some View {
        VStack(alignment: .leading, spacing: Layout.inline) {
            Text(kind.label).font(.title2.weight(.medium))
            if let application {
                Text(application.name).font(.headline)
                Text(application.metadata.status.label).font(.subheadline.weight(.semibold))
                Text(Copy.submitted + " " + application.metadata.submittedAt.label).font(.caption).foregroundStyle(Color.ufitMuted)
                if let review = application.metadata.latestReview, let notes = review.notes {
                    Divider()
                    Text(Copy.feedback).font(.subheadline.weight(.medium))
                    Text(notes).font(.callout)
                    Text(review.createdAt.label).font(.caption).foregroundStyle(Color.ufitMuted)
                }
                if application.metadata.status.canCorrect {
                    Button(action: { onCorrect(application) }) { Text(Copy.correct).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle())
                }
                if application.metadata.status == .accepted {
                    Button(Copy.payments, action: onPayments).frame(minHeight: Layout.touch)
                    if kind == .brand && canApply { Button(Copy.anotherBrand) { onApply(kind) }.frame(minHeight: Layout.touch) }
                }
            } else if canApply {
                Text(kind == .creator ? Copy.newCreator : Copy.newBrand).font(.callout).foregroundStyle(Color.ufitMuted)
                Button(action: { onApply(kind) }) { Text(kind.title).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle())
            }
        }.padding(Layout.spacing).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ufitBackground, in: RoundedRectangle(cornerRadius: Layout.radius))
    }
}
