import SwiftUI

struct CreatorProfileContentView: View {
    let displayName: String
    let creatorSlug: String
    let creatorStats: [CreatorStatSnapshot]
    let creatorGrade: CreatorGradeSnapshot
    let workspaceMessage: String?
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: .zero) {
            CreatorProfileNavigationBar(title: displayName, onBack: onBack)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: UFitSpace.xl) {
                        CreatorHeaderSection(
                            displayName: displayName,
                            slug: creatorSlug,
                            stats: creatorStats,
                            grade: creatorGrade,
                            statusMessage: workspaceMessage
                        )
                            .id(ProfileScrollAnchor.top)
                        PublishedOutfitsSection()
                    }
                }
                .scrollIndicators(.hidden)
                .background(Color.ufitCanvas)
                .onAppear {
                    scrollToTop(with: proxy)
                }
            }
        }
        .background(Color.ufitCanvas)
    }

    private func scrollToTop(with proxy: ScrollViewProxy) {
        Task { @MainActor in
            await Task.yield()
            proxy.scrollTo(ProfileScrollAnchor.top, anchor: .top)
        }
    }
}

private enum ProfileScrollAnchor {
    static let top = "creator-profile-top"
}

struct CreatorProfileNavigationBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: UFitSpace.sm) {
            UFitButton(action: onBack) {
                UFitIcon(systemName: "arrow.left")
                    .ufitFont(size: UFitTypography.Size.heading, weight: .regular)
                    .foregroundStyle(Color.ufitInk)
                    .frame(width: 30, height: 30)
            }
            .ufitButtonStyle(.text)

            Text(title)
                .ufitFont(size: UFitTypography.Size.section, weight: .semibold)
                .foregroundStyle(Color.ufitInk)

            Spacer()
        }
        .padding(.horizontal, UFitSpace.xl)
        .padding(.vertical, UFitSpace.md)
        .background(.white.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ufitBorder)
                .frame(height: 1)
        }
    }
}

struct CreatorHeaderSection: View {
    let displayName: String
    let slug: String
    let stats: [CreatorStatSnapshot]
    let grade: CreatorGradeSnapshot
    let statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xl) {
            HStack(alignment: .top, spacing: UFitSpace.md) {
                Text(initials)
                    .ufitFont(size: UFitTypography.Size.section, weight: .medium)
                    .foregroundStyle(Color.ufitInk)
                    .frame(width: 82, height: 82)
                    .background(Color.ufitSecondary, in: Circle())

                VStack(alignment: .leading, spacing: UFitSpace.sm) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName)
                            .ufitFont(size: UFitTypography.Size.section, weight: .medium)
                        Text(slug)
                            .ufitFont(size: UFitTypography.Size.small)
                            .foregroundStyle(Color.ufitSecondaryText)
                    }

                    UFitButton(action: {}) {
                        Text("Follow")
                            .frame(maxWidth: .infinity)
                    }
                    .ufitButtonStyle(.primary, compact: true)
                }

                Spacer()
            }

            if let statusMessage {
                Text(statusMessage)
                    .ufitFont(size: UFitTypography.Size.small)
                    .foregroundStyle(Color.ufitSecondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.action, style: .continuous))
            }

            Text("Parisian fashion curator. Minimalist aesthetic, timeless pieces. Collaborating with independent European brands to bring you sustainable, high-quality fashion.")
                .ufitFont(size: UFitTypography.Size.small)
                .lineSpacing(4)
                .foregroundStyle(Color.ufitSecondaryText)

            HStack(spacing: UFitSpace.sm) {
                ForEach(stats) { stat in
                    CreatorStatCard(icon: stat.icon, value: stat.value, label: stat.label)
                }
            }

            CreatorGradeCard(grade: grade)
        }
        .padding(.horizontal, UFitSpace.xl)
        .padding(.top, UFitSpace.xxl)
    }

    private var initials: String {
        displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
    }
}

struct CreatorStatSnapshot: Identifiable {
    let id = UUID()
    let icon: String
    let value: String
    let label: String
}

struct CreatorGradeSnapshot {
    let label: String
    let commissionRate: String
}

struct CreatorGradeCard: View {
    let grade: CreatorGradeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            HStack {
                Text("Creator Grade")
                    .ufitFont(size: UFitTypography.Size.small)
                    .foregroundStyle(Color.ufitSecondaryText)
                Spacer()
                Label(grade.label, systemImage: "medal")
                    .ufitFont(size: UFitTypography.Size.small, weight: .medium)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ufitCanvas)
                    Capsule()
                        .fill(Color.ufitInk)
                        .frame(width: proxy.size.width * 0.85)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Commission Rate")
                    .foregroundStyle(Color.ufitSecondaryText)
                Spacer()
                Text("\(grade.commissionRate) -> 15%")
            }
            .ufitFont(size: UFitTypography.Size.caption)

            Text("Keep publishing high-quality outfits to unlock the next creator tier.")
                .ufitFont(size: UFitTypography.Size.caption)
                .foregroundStyle(Color.ufitSecondaryText)
        }
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card, style: .continuous))
    }
}

struct PublishedOutfitsSection: View {
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            Text("Published Outfits")
                .ufitFont(size: UFitTypography.Size.section, weight: .medium)
                .padding(.horizontal, UFitSpace.xl)

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(SampleData.creatorImages, id: \.self) { imageName in
                    CreatorOutfitGridImage(imageName: imageName)
                }
            }
            .background(Color.ufitBorder)
        }
        .padding(.bottom, UFitSpace.xl)
    }
}

struct CreatorOutfitGridImage: View {
    let imageName: String

    var body: some View {
        Rectangle()
            .fill(Color.ufitCanvas)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }
}
