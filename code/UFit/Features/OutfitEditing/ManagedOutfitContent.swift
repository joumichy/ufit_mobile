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
    var renewPhotoSource: ((String) async throws -> String)? = nil
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
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch
        static let title: CGFloat = UFitTypography.Size.editorial; static let hero: CGFloat = 390; static let image: CGFloat = 76; static let radius: CGFloat = UFitRadius.field; static let editor: CGFloat = 150; static let bottom: CGFloat = 80
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let photo = "photo" }
    private var locked: Bool { isLoading || isMutating }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                if isLoading { UFitLoading().frame(width: Layout.touch, height: Layout.touch) }
                else { UFitButton(action: onRefresh) { UFitIcon(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh).disabled(isMutating) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(outfit.status.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        Text(outfit.title).ufitFont(size: Layout.title, design: .serif)
                        if let author = outfit.author { Text(author).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText) }
                        Text(outfit.price).font(UFitTypography.headline)
                    }
                    if outfit.photos.isEmpty {
                        Rectangle().fill(Color.ufitCanvas).overlay { Label(Copy.noPhotos, systemImage: Icon.photo) }.frame(height: Layout.hero)
                    } else {
                        UFitOutfitGalleryContent(photos: outfit.photos.enumerated().map { index, photo in
                            .init(url: photo.source, position: index, id: photo.id)
                        }, contentMode: .fit, imageHeight: Layout.hero, renewPhotoSource: renewPhotoSource)
                    }
                    if !outfit.description.isEmpty { Text(outfit.description).font(UFitTypography.body) }
                    if let gender = outfit.gender { Text(gender.label).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText) }
                    if !outfit.tags.isEmpty { Text(outfit.tags.map(\.label).joined(separator: Copy.separator)).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        Text(Copy.pieces).font(UFitTypography.title2.weight(.medium))
                        if outfit.pieces.isEmpty { Text(Copy.noPieces).foregroundStyle(Color.ufitSecondaryText) }
                        ForEach(outfit.pieces) { piece in
                            VStack(alignment: .leading, spacing: Layout.small) {
                                HStack(alignment: .top, spacing: Layout.gap) {
                                    if let source = piece.image { FashionImage(source: source).frame(width: Layout.image, height: Layout.image).clipShape(RoundedRectangle(cornerRadius: Layout.radius)) }
                                    VStack(alignment: .leading, spacing: Layout.small) {
                                        Text(piece.title).font(UFitTypography.headline)
                                        Text(piece.type.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                        if let price = piece.price { Text(price).font(UFitTypography.subheadline) }
                                        if !piece.isShoppable { Text(Copy.inspiration).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                                        else if !piece.isAvailable { Text(Copy.unavailable).font(UFitTypography.caption) }
                                        if piece.isRequired { Text(Copy.required).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                                    }
                                }
                                if let note = piece.note, !note.isEmpty { Text(note).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                                Divider()
                            }
                        }
                    }
                    if let reason = outfit.rejectionReason {
                        VStack(alignment: .leading, spacing: Layout.small) { Text(Copy.rejected).font(UFitTypography.headline); Text(reason).font(UFitTypography.callout) }
                    }
                    if let message { Text(message).font(UFitTypography.callout) }
                    if isMutating { UFitLoading(Copy.saving).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                    actions.disabled(locked)
                }.padding(Layout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(Copy.publishTitle, isPresented: $confirmingPublication, titleVisibility: .visible) {
                UFitButton(Copy.publish) { if let revision = decisionRevision { onApprove(revision) } }
                UFitButton(Copy.cancel, role: .cancel) {}
            }
            .ufitConfirmationDialog(Copy.archiveTitle, isPresented: $confirmingArchive, titleVisibility: .visible) {
                UFitButton(Copy.archive, role: .destructive) { if let revision = decisionRevision { onArchive(revision) } }
                UFitButton(Copy.cancel, role: .cancel) {}
            }
            .ufitSheet(isPresented: $showingRejection) { rejectionSheet }
    }
    @ViewBuilder private var actions: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            if outfit.status == .archived {
                UFitButton { onRestore(outfit.revision) } label: { Text(Copy.restore).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary)
            } else {
                if access == .author {
                    if outfit.status.canSubmit {
                        if let issue = outfit.submissionIssue { Text(issue).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                        UFitButton { onSubmit(outfit.revision) } label: { Text(Copy.submit).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).disabled(outfit.submissionIssue != nil)
                        UFitButton(Copy.edit, action: onEdit).frame(minHeight: Layout.touch)
                    } else if outfit.status.canEdit {
                        UFitButton(action: onEdit) { Text(Copy.edit).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary)
                    }
                } else if outfit.status == .underReview {
                    if let issue = outfit.submissionIssue { Text(issue).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                    UFitButton { decisionRevision = outfit.revision; confirmingPublication = true } label: { Text(Copy.publish).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).disabled(outfit.submissionIssue != nil)
                    UFitButton(Copy.reject) { decisionRevision = outfit.revision; rejection = String(); rejectionError = nil; showingRejection = true }.frame(minHeight: Layout.touch)
                }
                UFitButton(Copy.archive) { decisionRevision = outfit.revision; confirmingArchive = true }.frame(minHeight: Layout.touch)
            }
        }
    }
    private var rejectionSheet: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: Copy.reject, onClose: { showingRejection = false })
            VStack(alignment: .leading, spacing: Layout.gap) {
                UFitMultilineField(label: Copy.reason, text: $rejection, error: rejectionError)
                UFitButton {
                    guard UFitOutfitInput.textValid(rejection, minimum: UFitOutfitInput.labelMin, maximum: UFitOutfitInput.noteMax) else { rejectionError = Copy.reasonRequired; return }
                    if let revision = decisionRevision { onReject(revision, UFitOutfitInput.trimmed(rejection)); showingRejection = false }
                } label: { Text(Copy.reject).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary)
                Spacer()
            }.padding(Layout.page)
        }.tint(Color.ufitInk)
    }
}
