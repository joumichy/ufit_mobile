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
    @State private var confirmingDiscard = false
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
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44; static let radius: CGFloat = 12
        static let descriptionMinimum = 4; static let descriptionMaximum = 10
    }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: isNew ? Copy.new : Copy.edit, onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } }).disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    UFitTextField(label: Copy.title, text: $draft.title, error: errors[.title])
                    UFitOutfitPhotosContent(photos: $draft.photos, error: errors[.photos], onAdd: onAddPhotos, onRetry: onRetryPhoto, onRemove: onRemovePhoto)
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(Copy.description).font(.subheadline.weight(.medium))
                        TextField(Copy.description, text: $draft.description, axis: .vertical)
                            .lineLimit(Layout.descriptionMinimum...Layout.descriptionMaximum).padding(Layout.gap)
                            .overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }.accessibilityLabel(Copy.description)
                        if let error = errors[.description] { Text(error).font(.caption) }
                    }
                    UFitOutfitPiecesContent(pieces: $draft.pieces, error: errors[.pieces], onSelectProduct: onSelectProduct)
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(Copy.gender).font(.subheadline.weight(.medium))
                        Picker(Copy.gender, selection: $draft.gender) {
                            Text(Copy.unspecified).tag(Optional<UFitGenderTarget>.none)
                            ForEach(UFitGenderTarget.allCases) { Text($0.label).tag(Optional($0)) }
                        }.pickerStyle(.menu).frame(minHeight: Layout.touch)
                    }
                    DisclosureGroup(Copy.styles) {
                        VStack(alignment: .leading, spacing: Layout.gap) {
                            ForEach(UFitOutfitTagType.allCases) { type in
                                VStack(alignment: .leading, spacing: Layout.small) {
                                    Text(type.label).font(.headline)
                                    ForEach(tags.filter { $0.type == type }) { tag in
                                        Toggle(tag.label, isOn: Binding(get: { draft.tagIDs.contains(tag.id) }, set: { selected in
                                            if selected { draft.tagIDs.insert(tag.id) } else { draft.tagIDs.remove(tag.id) }
                                        })).frame(minHeight: Layout.touch)
                                    }
                                }
                            }
                            if !draft.tagIDs.isSubset(of: Set(tags.map(\.id))) { Button(Copy.removeUnavailable) { draft.tagIDs.formIntersection(tags.map(\.id)) }.frame(minHeight: Layout.touch) }
                            Button(Copy.reload, action: onReloadTags).frame(minHeight: Layout.touch)
                        }.padding(.top, Layout.gap)
                    }.frame(minHeight: Layout.touch)
                    if let error = errors[.tags] { Text(error).font(.caption) }
                    if changesPublishedOutfit { Text(Copy.changesPublication).font(.callout).foregroundStyle(Color.ufitMuted) }
                }.padding(Layout.page).disabled(isBusy)
            }.scrollDismissesKeyboard(.interactively)
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            VStack(alignment: .leading, spacing: Layout.small) {
                if let message { Text(message).font(.callout) }
                if isBusy { ProgressView(Copy.saving).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                else { Button(action: onSave) { Text(Copy.save).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).disabled(!hasChanges) }
            }.padding(Layout.gap).background(Color.white).overlay(alignment: .top) { Divider() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
            .confirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button(Copy.discard, role: .destructive, action: onBack)
                Button(Copy.keep, role: .cancel) {}
            }
    }
}
