import SwiftUI

struct RootScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.ufitInk)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Color.ufitMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(Color.white)
    }
}

struct SearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.ufitMuted)

            TextField("Style, creator, product", text: $query)
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .frame(height: 48)
        .padding(.horizontal, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.ufitBorder, lineWidth: 1)
        }
        .padding(.horizontal, 24)
    }
}

struct EmptySearchState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26))
                .foregroundStyle(Color.ufitMuted)
            Text("No looks found")
                .font(.system(size: 18, weight: .semibold))
            Text("Try a creator name, a style mood, or one product category.")
                .font(.system(size: 14))
                .foregroundStyle(Color.ufitMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct WorkspaceEntryCard: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let primaryMetric: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.ufitInk)
                    .frame(width: 44, height: 44)
                    .background(Color.ufitSecondary, in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.ufitInk)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ufitMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack {
                Text(primaryMetric)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.ufitInk)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.ufitSecondary, in: Capsule())

                Spacer()

                Button(action: action) {
                    HStack(spacing: 7) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(CompactPrimaryButtonStyle())
                .frame(width: 148)
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.ufitBorder, lineWidth: 1)
        }
    }
}

struct WorkspaceNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.ufitMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SavedOutfitRow: View {
    let outfit: Outfit

    var body: some View {
        HStack(spacing: 14) {
            FashionImage(source: outfit.imageName)
                .frame(width: 86, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(outfit.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.ufitInk)
                Text(outfit.creator)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.ufitMuted)
                Text(outfit.price)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.ufitInk)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.ufitBorder, lineWidth: 1)
        )
    }
}

struct EmptySavedState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 26))
                .foregroundStyle(Color.ufitMuted)
            Text("No saved outfits yet")
                .font(.system(size: 18, weight: .semibold))
            Text("Tap the heart on any outfit to keep it here.")
                .font(.system(size: 14))
                .foregroundStyle(Color.ufitMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
