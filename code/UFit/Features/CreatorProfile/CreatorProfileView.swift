import SwiftUI

struct CreatorProfileView: View {
    let store: MarketplaceStore
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            CreatorProfileNavigationBar(title: displayName, onBack: onBack)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
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
                .background(Color.white)
                .onAppear {
                    scrollToTop(with: proxy)
                }
            }
        }
        .background(Color.white)
        .task {
            await store.loadCreatorWorkspace()
        }
    }

    private var displayName: String {
        store.creatorDashboard?.profile.displayName ?? "Sofia Laurent"
    }

    private var creatorSlug: String {
        store.creatorDashboard.map { "@\($0.profile.slug)" } ?? "@sofialaurent"
    }

    private var creatorGrade: CreatorGradeSnapshot {
        guard let grade = store.creatorDashboard?.profile.grade else {
            return CreatorGradeSnapshot(label: "Elite", commissionRate: "12%")
        }
        return CreatorGradeSnapshot(label: grade.label, commissionRate: "\(grade.commissionBps / 100)%")
    }

    private var creatorStats: [CreatorStatSnapshot] {
        guard let performance = store.creatorDashboard?.performance else {
            return [
                CreatorStatSnapshot(icon: "person.2", value: "12.4k", label: "Followers"),
                CreatorStatSnapshot(icon: "shippingbox", value: "87", label: "Outfits"),
                CreatorStatSnapshot(icon: "medal", value: "Elite", label: "Grade")
            ]
        }

        return [
            CreatorStatSnapshot(icon: "shippingbox", value: "\(performance.outfits.total)", label: "Outfits"),
            CreatorStatSnapshot(icon: "bag", value: "\(performance.sales.paidOrderCount)", label: "Sales"),
            CreatorStatSnapshot(icon: "eurosign.circle", value: UFitMoney.format(performance.commissions.pendingAmount, currency: performance.sales.currency), label: "Pending")
        ]
    }

    private var workspaceMessage: String? {
        store.creatorDashboard == nil && !store.isAuthenticated ? "Connect a creator session to load live performance." : nil
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

private struct CreatorProfileNavigationBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color.ufitInk)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.ufitInk)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.white.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ufitBorder)
                .frame(height: 1)
        }
    }
}

private struct CreatorHeaderSection: View {
    let displayName: String
    let slug: String
    let stats: [CreatorStatSnapshot]
    let grade: CreatorGradeSnapshot
    let statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                Text(initials)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.ufitInk)
                    .frame(width: 82, height: 82)
                    .background(Color.ufitSecondary, in: Circle())

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName)
                            .font(.system(size: 22, weight: .medium))
                        Text(slug)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.ufitMuted)
                    }

                    Button(action: {}) {
                        Text("Follow")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompactPrimaryButtonStyle())
                }

                Spacer()
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.ufitMuted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Text("Parisian fashion curator. Minimalist aesthetic, timeless pieces. Collaborating with independent European brands to bring you sustainable, high-quality fashion.")
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(Color.ufitMuted)

            HStack(spacing: 12) {
                ForEach(stats) { stat in
                    CreatorStatCard(icon: stat.icon, value: stat.value, label: stat.label)
                }
            }

            CreatorGradeCard(grade: grade)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
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

private struct CreatorStatSnapshot: Identifiable {
    let id = UUID()
    let icon: String
    let value: String
    let label: String
}

private struct CreatorGradeSnapshot {
    let label: String
    let commissionRate: String
}

private struct CreatorGradeCard: View {
    let grade: CreatorGradeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Creator Grade")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.ufitMuted)
                Spacer()
                Label(grade.label, systemImage: "medal")
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
                Text("\(grade.commissionRate) -> 15%")
            }
            .font(.system(size: 12))

            Text("Keep publishing high-quality outfits to unlock the next creator tier.")
                .font(.system(size: 12))
                .foregroundStyle(Color.ufitMuted)
        }
        .padding(18)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PublishedOutfitsSection: View {
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Published Outfits")
                .font(.system(size: 20, weight: .medium))
                .padding(.horizontal, 24)

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(SampleData.creatorImages, id: \.self) { imageName in
                    CreatorOutfitGridImage(imageName: imageName)
                }
            }
            .background(Color.ufitBorder)
        }
        .padding(.bottom, 104)
    }
}

private struct CreatorOutfitGridImage: View {
    let imageName: String

    var body: some View {
        Rectangle()
            .fill(Color.white)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }
}

#Preview {
    CreatorProfileView(store: MarketplaceStore.live(), onBack: {})
}
