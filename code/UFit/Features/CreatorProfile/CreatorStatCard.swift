import SwiftUI

struct CreatorStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: UFitSpace.xs) {
            UFitIcon(systemName: icon)
                .ufitFont(size: UFitTypography.Size.heading)
                .foregroundStyle(Color.ufitSecondaryText)
            Text(value)
                .ufitFont(size: UFitTypography.Size.section, weight: .medium)
            Text(label)
                .ufitFont(size: UFitTypography.Size.micro)
                .foregroundStyle(Color.ufitSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.action, style: .continuous))
    }
}
