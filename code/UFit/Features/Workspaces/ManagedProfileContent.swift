import SwiftUI

struct UFitManagedProfileContent: View {
    @State private var confirmingDiscard = false
    let isCreator: Bool
    @Binding var draft: UFitManagedProfileDraft
    let errors: [UFitProfileField: String]
    let isBusy: Bool
    let hasChanges: Bool
    let message: String?
    let onBack: () -> Void
    let onSave: () -> Void
    private enum Copy {
        static let separator = " "
        static let discardTitle = String(localized: "Abandonner les modifications ?")
        static let discard = String(localized: "Abandonner")
        static let keepEditing = String(localized: "Continuer la modification")
        static let title = String(localized: "Mon profil")
        static let creator = String(localized: "Profil créateur")
        static let brand = String(localized: "Profil de marque")
        static let save = String(localized: "Enregistrer")
        static let creatorName = String(localized: "Nom public")
        static let brandName = String(localized: "Nom de la marque")
        static let bio = String(localized: "Bio")
        static let website = String(localized: "Site web (facultatif)")
        static let visibility = String(localized: "Statut du profil")
        static let socials = String(localized: "Réseaux et liens")
        static let add = String(localized: "Ajouter un réseau")
        static let handle = String(localized: "Identifiant public")
        static let url = String(localized: "Lien (facultatif)")
        static let remove = String(localized: "Retirer")
        static let suspended = String(localized: "Ce profil est suspendu. Les modifications sont désactivées.")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch
        static let title: CGFloat = UFitTypography.Size.editorial; static let field: CGFloat = UFitControlSize.input; static let editor: CGFloat = 130; static let radius: CGFloat = UFitRadius.field
    }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: { if hasChanges { confirmingDiscard = true } else { onBack() } }) {
                if isBusy { UFitLoading().frame(minWidth: Layout.touch, minHeight: Layout.touch) }
                else if draft.status.canEdit { UFitButton(Copy.save, action: onSave).font(UFitTypography.subheadline.weight(.semibold)).frame(minHeight: Layout.touch).disabled(!hasChanges) }
            }.disabled(isBusy)
            if let message { Text(message).font(UFitTypography.callout).frame(maxWidth: .infinity, alignment: .leading).padding(Layout.gap).background(Color.ufitCanvas).accessibilityAddTraits(.updatesFrequently) }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    Text(isCreator ? Copy.creator : Copy.brand).ufitFont(size: Layout.title, design: .serif)
                    if !draft.status.canEdit { Text(Copy.suspended).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                    field(isCreator ? Copy.creatorName : Copy.brandName, text: $draft.name, error: errors[.name])
                    UFitMultilineField(label: Copy.bio, text: $draft.bio, error: errors[.bio])
                    if !isCreator { field(Copy.website, text: $draft.website, error: errors[.website], isURL: true) }
                    VStack(alignment: .leading, spacing: Layout.small) {
                        if draft.status.canChangeVisibility {
                            Text(Copy.visibility).font(UFitTypography.subheadline.weight(.medium))
                            UFitSelection(Copy.visibility, selection: $draft.status, options: [UFitProfileStatus.active, .paused].map { .init(value: $0, title: $0.label) }).frame(minHeight: Layout.touch)
                        } else { UFitLabeledValue(Copy.visibility, value: draft.status.label) }
                    }
                    if isCreator { socialFields }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(isBusy || !draft.status.canEdit)
            }.scrollDismissesKeyboard(.interactively)
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(Copy.discardTitle, isPresented: $confirmingDiscard, titleVisibility: .visible) {
                UFitButton(Copy.discard, role: .destructive, action: onBack)
                UFitButton(Copy.keepEditing, role: .cancel) {}
            }
    }
    private var socialFields: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.socials).font(UFitTypography.title2.weight(.medium))
            ForEach($draft.socials) { $social in
                VStack(alignment: .leading, spacing: Layout.gap) {
                    HStack {
                        Text(social.platform.label).font(UFitTypography.headline)
                        Spacer()
                        UFitButton(Copy.remove) { draft.socials.removeAll { $0.platform == social.platform } }
                            .frame(minHeight: Layout.touch).accessibilityLabel(Copy.remove + Copy.separator + social.platform.label)
                    }
                    field(Copy.handle, text: $social.handle, error: errors[.handle(social.platform)], isIdentifier: true)
                    field(Copy.url, text: $social.url, error: errors[.socialURL(social.platform)], isURL: true)
                }.padding(Layout.gap).overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }
            }
            if !draft.availablePlatforms.isEmpty {
                UFitActionMenu(Copy.add) {
                    ForEach(draft.availablePlatforms) { platform in UFitButton(platform.label) { draft.socials.append(UFitSocialDraft(platform: platform)) } }
                }.frame(minHeight: Layout.touch)
            }
        }
    }
    private func field(_ label: String, text: Binding<String>, error: String?, isURL: Bool = false, isIdentifier: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Layout.small) {
            Text(label).font(UFitTypography.subheadline.weight(.medium))
            UFitInput(label, text: text, error: error).textInputAutocapitalization(isURL || isIdentifier ? .never : .words)
                .autocorrectionDisabled(isURL || isIdentifier).keyboardType(isURL ? .URL : .default)
                .accessibilityLabel(label)
            errorText(error)
        }
    }
    @ViewBuilder private func errorText(_ error: String?) -> some View {
        if let error { UFitFieldError(message: error).foregroundStyle(Color.ufitInk) }
    }
}
