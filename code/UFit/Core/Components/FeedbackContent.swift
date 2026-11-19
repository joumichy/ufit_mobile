import SwiftUI

enum UFitFeedbackCopy {
    static let loading = String(localized: "Chargement")
    static let retry = String(localized: "Réessayer")
    static let close = String(localized: "Fermer")
    static let choose = String(localized: "Choisir")
    static let search = String(localized: "Rechercher")
    static let empty = String(localized: "Aucun résultat")
    static let refresh = String(localized: "Actualiser")
}
struct UFitLoading: View {
    var title: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum Drawing { static let size: CGFloat = 20; static let stroke: CGFloat = 2; static let arc: CGFloat = 0.72; static let turn = 360.0; static let track = 0.18 }
    init(_ title: String? = nil) { self.title = title }
    var body: some View {
        HStack(spacing: UFitSpace.xs) {
            TimelineView(.animation(paused: reduceMotion)) { context in
                ZStack {
                    Circle().stroke(.foreground.opacity(Drawing.track), lineWidth: Drawing.stroke)
                    Circle().trim(from: .zero, to: Drawing.arc).stroke(style: StrokeStyle(lineWidth: Drawing.stroke, lineCap: .round))
                        .rotationEffect(.degrees(reduceMotion ? .zero : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: UFitMotion.spinner) / UFitMotion.spinner * Drawing.turn))
                }.frame(width: Drawing.size, height: Drawing.size)
            }.accessibilityHidden(true)
            if let title { Text(title).font(UFitTypography.callout).fixedSize(horizontal: false, vertical: true) }
        }.accessibilityElement(children: .ignore).accessibilityLabel(title ?? UFitFeedbackCopy.loading)
    }
}
enum UFitNoticeKind { case information, success, error }
struct UFitNotice: View {
    let message: String
    var kind: UFitNoticeKind = .information
    var onDismiss: (() -> Void)? = nil
    private enum Icon { static let close = "xmark" }
    private var symbol: String {
        switch kind { case .information: "info.circle"; case .success: "checkmark.circle"; case .error: "exclamationmark.circle" }
    }
    var body: some View {
        HStack(alignment: .top, spacing: UFitSpace.xs) {
            UFitIcon(systemName: symbol).accessibilityHidden(true)
            Text(message).font(UFitTypography.callout).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            if let onDismiss {
                UFitButton(action: onDismiss) { UFitIcon(systemName: Icon.close).font(UFitTypography.caption) }
                    .ufitButtonStyle(.text).accessibilityLabel(UFitFeedbackCopy.close)
            }
        }.foregroundStyle(kind == .error ? Color.ufitDanger : Color.ufitInk)
            .padding(UFitSpace.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(kind == .error ? Color.ufitDangerSurface : Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.field))
            .accessibilityElement(children: onDismiss == nil ? .combine : .contain)
    }
}
struct UFitEmptyState: View {
    let title: String
    var message: String? = nil
    var symbol = "square.grid.2x2"
    var actionTitle: String? = nil
    var actionKind: UFitButtonKind = .secondary
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: UFitSpace.md) {
            UFitIcon(systemName: symbol).font(UFitTypography.title).foregroundStyle(Color.ufitSecondaryText).accessibilityHidden(true)
            Text(title).font(UFitTypography.title3).accessibilityAddTraits(.isHeader)
            if let message { Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            if let actionTitle, let action { UFitActionButton(title: actionTitle, kind: actionKind, action: action) }
        }.multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .padding(UFitSpace.xl).frame(maxWidth: .infinity)
    }
}

struct UFitPullToRefresh: ViewModifier {
    let action: () async -> Void
    let isEnabled: Bool
    let accessibilityTitle: String
    @Environment(\.isEnabled) private var parentEnabled
    @State private var armed = false
    @State private var refreshing = false
    private enum GestureLayout { static let threshold: CGFloat = 96 }
    private var canRefresh: Bool { isEnabled && parentEnabled && !refreshing }
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 18.0, *) {
                content.onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top < -GestureLayout.threshold
                } action: { _, pulled in if pulled && canRefresh { armed = true } }
                    .onScrollPhaseChange { _, phase in if phase == .idle && armed { refresh() } }
                    .overlay(alignment: .top) { indicator }
            } else {
                content.simultaneousGesture(DragGesture().onEnded { gesture in
                    if gesture.startLocation.y < UFitControlSize.touch && gesture.translation.height > GestureLayout.threshold { refresh() }
                }).overlay(alignment: .top) { indicator }
            }
        }.scrollBounceBehavior(.always, axes: .vertical)
            .accessibilityActions {
                if canRefresh { Button(accessibilityTitle, action: refresh) }
            }
    }
    @ViewBuilder private var indicator: some View {
        if refreshing { UFitLoading().padding(UFitSpace.sm).background(Color.ufitCanvas, in: Capsule()).allowsHitTesting(false) }
    }
    private func refresh() {
        armed = false
        guard canRefresh else { return }
        refreshing = true
        Task { await action(); refreshing = false }
    }
}
extension View {
    func ufitRefreshable(isEnabled: Bool = true, title: String = UFitFeedbackCopy.refresh, action: @escaping () async -> Void) -> some View {
        modifier(UFitPullToRefresh(action: action, isEnabled: isEnabled, accessibilityTitle: title))
    }
}
