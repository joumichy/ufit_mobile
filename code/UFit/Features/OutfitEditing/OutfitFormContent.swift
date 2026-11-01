import SwiftUI

struct UFitOutfitFormContent: View {
    @Binding var draft: UFitOutfitDraft
    let tags: [UFitOutfitTag]
    let isNew: Bool
    let changesPublishedOutfit: Bool
    let hasChanges: Bool
    let isBusy: Bool
    let errors: [UFitOutfitField: String]
    let message: String?
    let onBack: () -> Void
    let onSave: () -> Void
    let onReloadTags: () -> Void
    let onAddPhotos: () -> Void
    let onRetryPhoto: (UUID) -> Void
    let onRemovePhoto: (UUID) -> Void
    let onSelectProduct: () -> Void
    var renewPhotoSource: ((UUID) async throws -> String)? = nil
    @State private var confirmingDiscard = false
    @State private var editingPhotoID: UUID?
    private enum Copy {
        static let new = String(localized: "Nouvelle tenue"); static let edit = String(localized: "Modifier la tenue")
        static let title = String(localized: "Titre de la tenue"); static let description = String(localized: "Description de la tenue")
        static let gender = String(localized: "Public (facultatif)"); static let unspecified = String(localized: "Non précisé")
        static let styles = String(localized: "Styles et occasions (facultatif)"); static let reload = String(localized: "Recharger les styles")
        static let removeUnavailable = String(localized: "Retirer les styles indisponibles")
        static let save = String(localized: "Enregistrer le brouillon"); static let saving = String(localized: "Enregistrement de la tenue")
        static let changesPublication = String(localized: "Ces modifications remettront la tenue en brouillon. Elle sera masquée jusqu’à sa prochaine validation.")
        static let discardTitle = String(localized: "Abandonner les modifications ?"); static let discard = String(localized: "Abandonner"); static let keep = String(localized: "Continuer la saisie")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch; static let radius: CGFloat = UFitRadius.field
        static let descriptionMinimum = 4; static let descriptionMaximum = 10
    }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: isNew ? Copy.new : Copy.edit, onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } }).disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    UFitOutfitPhotosContent(photos: $draft.photos, error: errors[.photos], onAdd: onAddPhotos, onRetry: onRetryPhoto, onRemove: onRemovePhoto, onPins: { editingPhotoID = $0 })
                    UFitOutfitPiecesContent(pieces: $draft.pieces, error: errors[.pieces], onSelectProduct: onSelectProduct)
                    UFitEditorialHeading(title: AuthoringCopy.intention, editorial: false)
                    UFitTextField(label: Copy.title, text: $draft.title, error: errors[.title])
                    UFitMultilineField(label: Copy.description, text: $draft.description, error: errors[.description])
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(Copy.gender).font(UFitTypography.subheadline.weight(.medium))
                        UFitSelection(Copy.gender, selection: $draft.gender, options: [.init(value: nil, title: Copy.unspecified)] + UFitGenderTarget.allCases.map { .init(value: Optional($0), title: $0.label) }).frame(minHeight: Layout.touch)
                    }
                    UFitDisclosure(Copy.styles) {
                        VStack(alignment: .leading, spacing: Layout.gap) {
                            ForEach(UFitOutfitTagType.allCases) { type in
                                VStack(alignment: .leading, spacing: Layout.small) {
                                    Text(type.label).font(UFitTypography.headline)
                                    ForEach(tags.filter { $0.type == type }) { tag in
                                        UFitToggle(tag.label, isOn: Binding(get: { draft.tagIDs.contains(tag.id) }, set: { selected in
                                            if selected { draft.tagIDs.insert(tag.id) } else { draft.tagIDs.remove(tag.id) }
                                        })).frame(minHeight: Layout.touch)
                                    }
                                }
                            }
                            if !draft.tagIDs.isSubset(of: Set(tags.map(\.id))) { UFitButton(Copy.removeUnavailable) { draft.tagIDs.formIntersection(tags.map(\.id)) }.frame(minHeight: Layout.touch) }
                            UFitButton(Copy.reload, action: onReloadTags).frame(minHeight: Layout.touch)
                        }.padding(.top, Layout.gap)
                    }.frame(minHeight: Layout.touch)
                    if let error = errors[.tags] { UFitFieldError(message: error) }
                    if changesPublishedOutfit { Text(Copy.changesPublication).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                }.padding(Layout.page).disabled(isBusy)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            VStack(alignment: .leading, spacing: Layout.small) {
                if let message { Text(message).font(UFitTypography.callout) }
                if isBusy { UFitLoading(Copy.saving).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                else { UFitButton(action: onSave) { Text(Copy.save).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).disabled(!hasChanges) }
            }.padding(Layout.gap).background(Color.ufitCanvas).overlay(alignment: .top) { Divider() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .onChange(of: draft.pieces.map(\.id)) { _, identities in
                for index in draft.photos.indices { draft.photos[index].pins.removeAll { !identities.contains($0.pieceID) } }
            }
            .ufitSheet(isPresented: Binding(get: { editingPhotoID != nil }, set: { if !$0 { editingPhotoID = nil } })) {
                if let id = editingPhotoID, let index = draft.photos.firstIndex(where: { $0.id == id }) {
                    UFitOutfitPinsContent(photo: $draft.photos[index], pieces: draft.pieces, onClose: { editingPhotoID = nil },
                        renewSource: renewPhotoSource.map { renew in { () async throws -> String in try await renew(id) } })
                }
            }
            .ufitConfirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                UFitButton(Copy.discard, role: .destructive, action: onBack)
                UFitButton(Copy.keep, role: .cancel) {}
            }
    }
}

private enum AuthoringCopy {
    static let intention = String(localized: "L’intention du look")
}
