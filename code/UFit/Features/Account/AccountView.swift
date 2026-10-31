import SwiftUI

struct UFitAccountView: View {
    let name: String
    let email: String
    let isBusy: Bool
    let message: String?
    let onSaveName: (String) -> Void
    let onSignOut: () -> Void
    var onOrders: (() -> Void)?
    @State private var editing = false
    @State private var editedName = String()
    private enum Copy {
        static let orders = String(localized: "Mes commandes")
        static let ordersIcon = "bag"
        static let title = String(localized: "Mon compte")
        static let edit = String(localized: "Modifier mon profil")
        static let name = String(localized: "Nom affiché")
        static let save = String(localized: "Enregistrer")
        static let cancel = String(localized: "Annuler")
        static let signOut = String(localized: "Se déconnecter")
        static let person = "person.crop.circle"
        static let editIcon = "pencil"
        static let exitIcon = "rectangle.portrait.and.arrow.right"
    }
    private enum Layout {
        static let spacing: CGFloat = 24
        static let portrait: CGFloat = 64
        static let title: CGFloat = 32
        static let radius: CGFloat = 14
        static let bottom: CGFloat = 100
        static let touch: CGFloat = 44
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.spacing) {
                Text(Copy.title).font(.system(size: Layout.title, weight: .regular, design: .serif))
                HStack(spacing: Layout.spacing) {
                    Image(systemName: Copy.person).font(.system(size: Layout.portrait, weight: .ultraLight))
                    VStack(alignment: .leading) {
                        if !name.isEmpty { Text(name).font(.title3.weight(.semibold)) }
                        Text(email).font(.subheadline).foregroundStyle(Color.ufitMuted)
                    }
                }
                if editing {
                    VStack(alignment: .leading, spacing: Layout.spacing) {
                        Text(Copy.name).font(.subheadline.weight(.medium))
                        TextField(Copy.name, text: $editedName).textContentType(.name)
                            .padding().background(Color.ufitBackground, in: RoundedRectangle(cornerRadius: Layout.radius))
                        Button(action: { onSaveName(editedName) }) {
                            HStack { Spacer(); if isBusy { ProgressView().tint(.white) } else { Text(Copy.save) }; Spacer() }
                        }.buttonStyle(PrimaryButtonStyle()).disabled(isBusy || editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editedName == name)
                        Button(Copy.cancel) { editing = false }.disabled(isBusy)
                    }
                } else {
                    Button { editedName = name; editing = true } label: { Label(Copy.edit, systemImage: Copy.editIcon) }
                }
                if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted) }
                Divider()
                if let onOrders { Button(action: onOrders) { Label(Copy.orders, systemImage: Copy.ordersIcon) }.frame(minHeight: Layout.touch) }
                Button(action: onSignOut) { Label(Copy.signOut, systemImage: Copy.exitIcon) }.disabled(isBusy)
            }
            .padding(Layout.spacing)
            .padding(.bottom, Layout.bottom)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color.ufitInk).background(Color.white)
        .buttonStyle(.plain)
        .onChange(of: name) { _, _ in editing = false }
    }
}
