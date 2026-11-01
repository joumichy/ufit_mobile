import SwiftUI

struct UFitManagedOutfitContent: View {
    let outfit: UFitManagedOutfitPresentation
    let access: UFitOutfitAccess
    let isLoading: Bool
    let isMutating: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let onSubmit: (UFitOutfitRevision) -> Void
    let onApprove: (UFitOutfitRevision) -> Void
    let onReject: (UFitOutfitRevision, String) -> Void
    let onArchive: (UFitOutfitRevision) -> Void
    let onRestore: (UFitOutfitRevision) -> Void
    @State private var confirmingPublication = false
    @State private var confirmingArchive = false
    @State private var showingRejection = false
    @State private var decisionRevision: UFitOutfitRevision?
    @State private var rejection = String()
    @State private var rejectionError: String?
    private enum Copy {
        static let refresh = String(localized: "Actualiser la tenue"); static let pieces = String(localized: "Les pièces")
        static let noPhotos = String(localized: "Aucune photo"); static let noPieces = String(localized: "Aucune pièce")
        static let description = String(localized: "Description"); static let inspiration = String(localized: "Inspiration · non vendue sur Ufit")
        static let unavailable = String(localized: "Produit indisponible"); static let required = String(localized: "Pièce essentielle")
        static let edit = String(localized: "Modifier la tenue"); static let submit = String(localized: "Envoyer à validation")
        static let publish = String(localized: "Publier cette tenue"); static let reject = String(localized: "Demander une correction")
        static let restore = String(localized: "Restaurer le brouillon"); static let archive = String(localized: "Archiver la tenue")
        static let archiveTitle = String(localized: "Masquer et archiver cette tenue ?"); static let publishTitle = String(localized: "Rendre cette tenue publique ?")
        static let cancel = String(localized: "Annuler"); static let reason = String(localized: "Motif de la correction")
        static let reasonRequired = String(localized: "Ajoutez un motif de 1 à 2 000 caractères.")
        static let rejected = String(localized: "Correction demandée"); static let saving = String(localized: "Mise à jour de la tenue")
        static let photo = String(localized: "Photo de la tenue"); static let separator = " · "
    }
    private enum Layout {
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44
        static let title: CGFloat = 32; static let hero: CGFloat = 390; static let image: CGFloat = 76; static let radius: CGFloat = 12; static let editor: CGFloat = 150; static let bottom: CGFloat = 80
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let photo = "photo" }
    private var locked: Bool { isLoading || isMutating }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                else { Button(action: onRefresh) { Image(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh).disabled(isMutating) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(outfit.status.label).font(.caption).foregroundStyle(Color.ufitMuted)
                        Text(outfit.title).font(.system(size: Layout.title, design: .serif))
                        if let author = outfit.author { Text(author).font(.subheadline).foregroundStyle(Color.ufitMuted) }
                        Text(outfit.price).font(.headline)
                    }
                    if outfit.photos.isEmpty {
                        Rectangle().fill(Color.ufitBackground).overlay { Label(Copy.noPhotos, systemImage: Icon.photo) }.frame(height: Layout.hero)
                    } else {
                        TabView {
                            ForEach(outfit.photos) { photo in
                                FashionImage(source: photo.source).clipped().accessibilityLabel(Copy.photo)
                            }
                        }.tabViewStyle(.page(indexDisplayMode: outfit.photos.count > UFitOutfitInput.positionStep ? .always : .never)).frame(height: Layout.hero)
                    }
                    if !outfit.description.isEmpty { Text(outfit.description).font(.body) }
                    if let gender = outfit.gender { Text(gender.label).font(.subheadline).foregroundStyle(Color.ufitMuted) }
                    if !outfit.tags.isEmpty { Text(outfit.tags.map(\.label).joined(separator: Copy.separator)).font(.callout).foregroundStyle(Color.ufitMuted) }
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        Text(Copy.pieces).font(.title2.weight(.medium))
                        if outfit.pieces.isEmpty { Text(Copy.noPieces).foregroundStyle(Color.ufitMuted) }
                        ForEach(outfit.pieces) { piece in
                            VStack(alignment: .leading, spacing: Layout.small) {
                                HStack(alignment: .top, spacing: Layout.gap) {
                                    if let source = piece.image { FashionImage(source: source).frame(width: Layout.image, height: Layout.image).clipShape(RoundedRectangle(cornerRadius: Layout.radius)) }
                                    VStack(alignment: .leading, spacing: Layout.small) {
                                        Text(piece.title).font(.headline)
                                        Text(piece.type.label).font(.caption).foregroundStyle(Color.ufitMuted)
                                        if let price = piece.price { Text(price).font(.subheadline) }
                                        if !piece.isShoppable { Text(Copy.inspiration).font(.caption).foregroundStyle(Color.ufitMuted) }
                                        else if !piece.isAvailable { Text(Copy.unavailable).font(.caption) }
                                        if piece.isRequired { Text(Copy.required).font(.caption).foregroundStyle(Color.ufitMuted) }
                                    }
                                }
                                if let note = piece.note, !note.isEmpty { Text(note).font(.callout).foregroundStyle(Color.ufitMuted) }
                                Divider()
                            }
                        }
                    }
                    if let reason = outfit.rejectionReason {
                        VStack(alignment: .leading, spacing: Layout.small) { Text(Copy.rejected).font(.headline); Text(reason).font(.callout) }
                    }
                    if let message { Text(message).font(.callout) }
                    if isMutating { ProgressView(Copy.saving).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                    actions.disabled(locked)
                }.padding(Layout.page).padding(.bottom, Layout.bottom).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
            .confirmationDialog(Copy.publishTitle, isPresented: $confirmingPublication, titleVisibility: .visible) {
                Button(Copy.publish) { if let revision = decisionRevision { onApprove(revision) } }
                Button(Copy.cancel, role: .cancel) {}
            }
            .confirmationDialog(Copy.archiveTitle, isPresented: $confirmingArchive, titleVisibility: .visible) {
                Button(Copy.archive, role: .destructive) { if let revision = decisionRevision { onArchive(revision) } }
                Button(Copy.cancel, role: .cancel) {}
            }
            .sheet(isPresented: $showingRejection) { rejectionSheet }
    }
    @ViewBuilder private var actions: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            if outfit.status == .archived {
                Button { onRestore(outfit.revision) } label: { Text(Copy.restore).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle())
            } else {
                if access == .author {
                    if outfit.status.canSubmit {
                        if let issue = outfit.submissionIssue { Text(issue).font(.callout).foregroundStyle(Color.ufitMuted) }
                        Button { onSubmit(outfit.revision) } label: { Text(Copy.submit).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).disabled(outfit.submissionIssue != nil)
                        Button(Copy.edit, action: onEdit).frame(minHeight: Layout.touch)
                    } else if outfit.status.canEdit {
                        Button(action: onEdit) { Text(Copy.edit).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle())
                    }
                } else if outfit.status == .underReview {
                    if let issue = outfit.submissionIssue { Text(issue).font(.callout).foregroundStyle(Color.ufitMuted) }
                    Button { decisionRevision = outfit.revision; confirmingPublication = true } label: { Text(Copy.publish).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).disabled(outfit.submissionIssue != nil)
                    Button(Copy.reject) { decisionRevision = outfit.revision; rejection = String(); rejectionError = nil; showingRejection = true }.frame(minHeight: Layout.touch)
                }
                Button(Copy.archive) { decisionRevision = outfit.revision; confirmingArchive = true }.frame(minHeight: Layout.touch)
            }
        }
    }
    private var rejectionSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Layout.gap) {
                Text(Copy.reason).font(.headline)
                TextEditor(text: $rejection).frame(minHeight: Layout.editor).padding(Layout.small)
                    .overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }.accessibilityLabel(Copy.reason)
                if let rejectionError { Text(rejectionError).font(.caption) }
                Button {
                    guard UFitOutfitInput.textValid(rejection, minimum: UFitOutfitInput.labelMin, maximum: UFitOutfitInput.noteMax) else { rejectionError = Copy.reasonRequired; return }
                    if let revision = decisionRevision { onReject(revision, UFitOutfitInput.trimmed(rejection)); showingRejection = false }
                } label: { Text(Copy.reject).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle())
                Spacer()
            }.padding(Layout.page).navigationTitle(Copy.reject).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(Copy.cancel) { showingRejection = false } } }
        }.tint(Color.ufitInk)
    }
}
