import SwiftUI

struct CreatorProfileView: View {
    let onBack: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]

    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(title: "Sofia Laurent", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CreatorHeaderSection()
                    PublishedOutfitsSection(columns: columns)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.white)
        }
        .background(Color.white)
    }
}

private struct CreatorHeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 16) {
                Text("SL")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.ufitInk)
                    .frame(width: 82, height: 82)
                    .background(Color.ufitSecondary, in: Circle())

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sofia Laurent")
                            .font(.system(size: 22, weight: .medium))
                        Text("@sofialaurent")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.ufitMuted)
                    }

                    Button("Follow") {}
                        .buttonStyle(CompactPrimaryButtonStyle())
                }

                Spacer()
            }

            Text("Parisian fashion curator. Minimalist aesthetic, timeless pieces. Collaborating with independent European brands to bring you sustainable, high-quality fashion.")
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(Color.ufitMuted)

            HStack(spacing: 12) {
                CreatorStatCard(icon: "person.2", value: "12.4k", label: "Followers")
                CreatorStatCard(icon: "shippingbox", value: "87", label: "Outfits")
                CreatorStatCard(icon: "medal", value: "Elite", label: "Grade")
            }

            CreatorGradeCard()
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
    }
}

private struct CreatorGradeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Creator Grade")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.ufitMuted)
                Spacer()
                Label("Elite", systemImage: "medal")
                    .font(.system(size: 14, weight: .medium))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white)
                    Capsule()
                        .fill(Color.ufitInk)
                        .frame(width: proxy.size.width * 0.85)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Commission Rate")
                    .foregroundStyle(Color.ufitMuted)
                Spacer()
                Text("12% -> 15%")
            }
            .font(.system(size: 12))

            Text("85 sales to reach Premium tier and unlock 15% commission")
                .font(.system(size: 12))
                .foregroundStyle(Color.ufitMuted)
        }
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PublishedOutfitsSection: View {
    let columns: [GridItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Published Outfits")
                .font(.system(size: 20, weight: .medium))
                .padding(.horizontal, 24)

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(SampleData.creatorImages, id: \.self) { imageName in
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(3.0 / 4.0, contentMode: .fill)
                        .clipped()
                }
            }
            .background(Color.ufitBorder)
        }
        .padding(.bottom, 104)
    }
}

#Preview {
    CreatorProfileView(onBack: {})
}
