import SwiftUI

struct UFitAuthenticationEntryContent: View {
    let message: String?
    let messageKind: UFitNoticeKind
    let onSignIn: () -> Void
    let onSignUp: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum Media {
        static let film = "auth-fashion"
        static let fileExtension = "mp4"
        static let poster = "AuthFashionPoster"
        static let topScrimOpacity = 0.50
        static let bottomScrimOpacity = 0.78
        static let topScrimHold: CGFloat = 0.28
        static let topScrimEnd: CGFloat = 0.48
        static let bottomScrimStart: CGFloat = 0.55
        static let minimumExtent: CGFloat = 0
        static let maximumExtent: CGFloat = 1
    }
    private enum Layout {
        static let maximumActionsWidth: CGFloat = 400
        static let logoTop = UFitSpace.editorial
        static let minimumSpace = UFitSpace.editorial
    }
    private enum Copy {
        static let signUp = String(localized: "S’inscrire")
    }
    var body: some View {
        ZStack {
            background.ignoresSafeArea().accessibilityHidden(true).allowsHitTesting(false)
            VStack(spacing: Layout.minimumSpace) {
                UFitWordmark(size: .display, color: .ufitCanvas)
                    .padding(.top, Layout.logoTop)
                Spacer(minLength: Layout.minimumSpace)
                VStack(spacing: UFitSpace.sm) {
                    if let message { UFitNotice(message: message, kind: messageKind) }
                    UFitActionButton(title: UFitAuthenticationCopy.signIn, kind: .inversePrimary, action: onSignIn)
                    UFitActionButton(title: Copy.signUp, kind: .inverseSecondary, action: onSignUp)
                }.frame(maxWidth: Layout.maximumActionsWidth)
                    .padding(.bottom, UFitSpace.xl)
            }.padding(.horizontal, UFitSpace.page)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ufitInk)
            .preferredColorScheme(.dark)
    }
    private var background: some View {
        GeometryReader { geometry in
            Group {
                if reduceMotion {
                    Image(Media.poster).resizable().scaledToFill()
                } else {
                    UFitLoopingVideoBackground(url: Bundle.main.url(forResource: Media.film, withExtension: Media.fileExtension),
                        posterName: Media.poster, isActive: scenePhase == .active)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .overlay {
                    LinearGradient(stops: [
                        .init(color: Color.ufitInk.opacity(Media.topScrimOpacity), location: Media.minimumExtent),
                        .init(color: Color.ufitInk.opacity(Media.topScrimOpacity), location: Media.topScrimHold),
                        .init(color: .clear, location: Media.topScrimEnd),
                        .init(color: .clear, location: Media.bottomScrimStart),
                        .init(color: Color.ufitInk.opacity(Media.bottomScrimOpacity), location: Media.maximumExtent)
                    ], startPoint: .top, endPoint: .bottom)
                }
        }
    }
}
