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
    let onPublish: (UFitOutfitRevision) -> Void
    let onWithdraw: (UFitOutfitRevision) -> Void
    let onArchive: (UFitOutfitRevision) -> Void
    let onRestore: (UFitOutfitRevision) -> Void
    var renewPhotoSource: ((String) async throws -> String)? = nil
    var onPublication: (() -> Void)? = nil
    @State private var confirmingPublication = false
    @State private var confirmingArchive = false
    @State private var decisionRevision: UFitOutfitRevision?
    private enum Copy {
        static let refresh = String(localized: "Actualiser la tenue"), pieces = String(localized: "Les pièces")
        static let noPhotos = String(localized: "Aucune photo"), noPieces = String(localized: "Aucune pièce")
        static let inspiration = String(localized: "Inspiration · non vendue sur Ufit")
        static let unavailable = String(localized: "Produit indisponible"), required = String(localized: "Pièce essentielle")
        static let edit = String(localized: "Modifier la tenue"), publish = String(localized: "Publier la tenue")
        static let publishNow = String(localized: "Publier maintenant"), withdraw = String(localized: "Retirer de la publication")
        static let schedule = String(localized: "Programmer la publication"), reschedule = String(localized: "Modifier la programmation")
        static let restore = String(localized: "Restaurer le brouillon"), archive = String(localized: "Archiver la tenue")
        static let archiveTitle = String(localized: "Masquer et archiver cette tenue ?")
        static let publishTitle = String(localized: "Publier cette tenue maintenant ?")
        static let cancel = String(localized: "Annuler"), saving = String(localized: "Mise à jour de la tenue")
        static let separator = " · "
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch
        static let title: CGFloat = UFitTypography.Size.editorial; static let hero: CGFloat = 390; static let image: CGFloat = 76; static let radius: CGFloat = UFitRadius.field; static let editor: CGFloat = 150; static let bottom: CGFloat = 80
    }
    private enum Icon { static let photo = "photo" }
    private var locked: Bool { isLoading || isMutating }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                if isLoading { UFitLoading().frame(width: Layout.touch, height: Layout.touch) }
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
                        }, contentMode: .fit, imageHeight: Layout.hero, surface: outfit.photos.count > 1 ? .neutral : .canvas,
                            adaptsToImage: true, renewPhotoSource: renewPhotoSource)
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
                    if let date = outfit.scheduledFor, let zoneID = outfit.publicationTimeZone, let zone = TimeZone(identifier: zoneID) {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(UFitPublicationFormatting.text(date, template: .time, zone: zone)).font(UFitTypography.headline)
                            Text(zoneID).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        }
                    }
                    if let message {
                        Text(message).font(UFitTypography.callout)
                        UFitActionButton(title: Copy.refresh, kind: .secondary, disabled: locked, action: onRefresh)
                    }
                    if isMutating { UFitLoading(Copy.saving).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                    actions.disabled(locked)
                }.padding(Layout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable(isEnabled: !locked, title: Copy.refresh) { onRefresh() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(Copy.publishTitle, isPresented: $confirmingPublication, titleVisibility: .visible) {
                UFitButton(Copy.publishNow) { if let revision = decisionRevision { onPublish(revision) } }
                UFitButton(Copy.cancel, role: .cancel) {}
            }
            .ufitConfirmationDialog(Copy.archiveTitle, isPresented: $confirmingArchive, titleVisibility: .visible) {
                UFitButton(Copy.archive, role: .destructive) { if let revision = decisionRevision { onArchive(revision) } }
                UFitButton(Copy.cancel, role: .cancel) {}
            }
    }
    @ViewBuilder private var actions: some View {
        VStack(spacing: Layout.gap) {
            if outfit.status == .archived {
                UFitActionButton(title: Copy.restore, isBusy: isMutating, disabled: isLoading) { onRestore(outfit.revision) }
            } else {
                if access == .author {
                    if let issue = outfit.publicationIssue { UFitNotice(message: issue, kind: .information) }
                    if outfit.status == .draft {
                        UFitActionButton(title: Copy.publish, isBusy: isMutating, disabled: isLoading || outfit.publicationIssue != nil) { onPublish(outfit.revision) }
                    }
                    if outfit.status != .published, let onPublication {
                        UFitActionButton(title: outfit.status == .scheduled ? Copy.reschedule : Copy.schedule,
                            kind: outfit.status == .scheduled ? .primary : .secondary,
                            disabled: isLoading || isMutating || (outfit.publicationIssue != nil && outfit.scheduledFor == nil), action: onPublication)
                    }
                    if outfit.status == .scheduled {
                        UFitActionButton(title: Copy.publishNow, kind: .secondary, disabled: locked || outfit.publicationIssue != nil) {
                            decisionRevision = outfit.revision; confirmingPublication = true
                        }
                    }
                    if outfit.status.canEdit { UFitActionButton(title: Copy.edit, kind: .secondary, disabled: locked, action: onEdit) }
                    if outfit.status == .published {
                        UFitActionButton(title: Copy.withdraw, kind: .secondary, role: .destructive, disabled: locked) { onWithdraw(outfit.revision) }
                    }
                }
                UFitActionButton(title: Copy.archive, kind: .secondary, role: .destructive, disabled: locked) {
                    decisionRevision = outfit.revision; confirmingArchive = true
                }.padding(.top, UFitSpace.xs)
            }
        }
    }
}
