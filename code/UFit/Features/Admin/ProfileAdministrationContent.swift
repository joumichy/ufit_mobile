import SwiftUI

struct UFitProfileAdministrationHost: View {
    let store: UFitProfileAdministrationStore
    let onBack: () -> Void
    @State private var confirmingDiscard = false
    @State private var leavingDetail = false
    var body: some View {
        @Bindable var form = store
        Group {
            if !store.isCurrentAccount {
                UFitEmptyState(title: UFitUserAdministrationCopy.unavailable, actionTitle: UFitUserAdministrationCopy.back, action: onBack)
            } else if let profile = store.selected {
                UFitProfileAdministrationDetailContent(profile: profile, history: store.history, decision: store.decision, reason: $form.reason,
                    reasonError: store.reasonError, message: store.detailMessage, messageIsError: store.detailMessageIsError,
                    isLoading: store.isDetailLoading, hasLoadedHistory: store.hasLoadedHistory, hasMore: store.historyCursor != nil,
                    isSaving: store.isSaving, canSave: store.canSave, requiresReferenceReload: store.requiresReferenceReload,
                    onBack: { if store.hasDraft { leavingDetail = true; confirmingDiscard = true } else { store.closeDetail() } },
                    onChoose: store.chooseDecision, onCancel: { if store.hasDraft { leavingDetail = false; confirmingDiscard = true } else { store.cancelDecision() } },
                    onRefresh: { Task { await store.loadDetail() } }, onMore: { Task { await store.loadDetail(refresh: false) } },
                    onSave: { Task { await store.save() } })
                    .onChange(of: store.reason) { _, _ in store.clearReasonError() }
            } else {
                UFitProfileAdministrationListContent(profiles: store.profiles,
                    kind: Binding(get: { store.kind }, set: { kind in Task { await store.chooseKind(kind) } }),
                    isLoading: store.isLoading, hasLoaded: store.hasLoaded, openingIDs: store.openingIDs,
                    hasMore: store.nextCursor != nil, message: store.listMessage, onBack: onBack,
                    onRefresh: { Task { await store.load() } }, onMore: { Task { await store.load(refresh: false) } },
                    onOpen: { id in Task { await store.open(id) } })
            }
        }.task { await store.load() }.onDisappear { store.cancelLoading() }
            .ufitConfirmationDialog(UFitUserAdministrationCopy.discardTitle, isPresented: $confirmingDiscard) {
                UFitButton(UFitUserAdministrationCopy.discard, role: .destructive) {
                    if leavingDetail { store.closeDetail() } else { store.cancelDecision() }
                }
                UFitButton(UFitUserAdministrationCopy.keepEditing, role: .cancel) {}
            }
    }
}

struct UFitProfileAdministrationListContent: View {
    let profiles: [UFitAdministeredProfileDTO]
    @Binding var kind: UFitAdministeredProfileKind
    let isLoading: Bool; let hasLoaded: Bool; let openingIDs: Set<String>; let hasMore: Bool; let message: String?
    let onBack: () -> Void; let onRefresh: () -> Void; let onMore: () -> Void; let onOpen: (String) -> Void
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitProfileAdministrationCopy.title, onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    UFitChoiceBar(title: UFitProfileAdministrationCopy.kind, selection: $kind,
                        options: UFitAdministeredProfileKind.allCases.map { .init(value: $0, title: $0.title) })
                    if let message {
                        UFitNotice(message: message, kind: .error)
                        UFitButton(UFitUserAdministrationCopy.retry, action: onRefresh).ufitButtonStyle(.secondary).disabled(isLoading)
                    }
                    if profiles.isEmpty {
                        if isLoading || (!hasLoaded && message == nil) { UFitLoading(UFitProfileAdministrationCopy.loading).frame(maxWidth: .infinity) }
                        else if hasLoaded && message == nil { UFitEmptyState(title: UFitProfileAdministrationCopy.empty, symbol: UFitProfileAdministrationCopy.icon) }
                    } else {
                        LazyVStack(spacing: .zero) {
                            ForEach(profiles) { profile in
                                VStack(spacing: .zero) {
                                    UFitButton { onOpen(profile.id) } label: {
                                        HStack(spacing: UFitSpace.md) {
                                            VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                                Text(profile.name).font(UFitTypography.headline)
                                                Text(profile.status.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                            }.fixedSize(horizontal: false, vertical: true)
                                            Spacer(minLength: UFitSpace.sm)
                                            if openingIDs.contains(profile.id) { UFitLoading() }
                                            else { UFitIcon(systemName: UFitProfileAdministrationCopy.nextIcon).accessibilityHidden(true) }
                                        }.frame(maxWidth: .infinity, minHeight: UFitControlSize.touch, alignment: .leading).padding(.vertical, UFitSpace.sm)
                                    }.disabled(openingIDs.contains(profile.id))
                                    Divider()
                                }
                            }
                        }
                        if isLoading { UFitLoading().frame(maxWidth: .infinity) }
                        if hasMore { UFitButton(UFitUserAdministrationCopy.more, action: onMore).ufitButtonStyle(.secondary).disabled(isLoading) }
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable(isEnabled: !isLoading, title: UFitUserAdministrationCopy.refresh) { onRefresh() }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}

struct UFitProfileAdministrationDetailContent: View {
    let profile: UFitAdministeredProfileDTO; let history: [UFitProfileStatusChangeDTO]; let decision: UFitProfileStatus?
    @Binding var reason: String
    let reasonError: String?; let message: String?; let messageIsError: Bool
    let isLoading: Bool; let hasLoadedHistory: Bool; let hasMore: Bool; let isSaving: Bool; let canSave: Bool; let requiresReferenceReload: Bool
    let onBack: () -> Void; let onChoose: (UFitProfileStatus) -> Void; let onCancel: () -> Void
    let onRefresh: () -> Void; let onMore: () -> Void; let onSave: () -> Void
    private var decisions: [UFitProfileStatus] { [.active, .paused, .suspended].filter(profile.allows) }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: decision.map(UFitProfileAdministrationCopy.action) ?? UFitProfileAdministrationCopy.status, onBack: onBack).disabled(isSaving)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                        Text(profile.name).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                        Text(profile.kind.profileLabel).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    }
                    UFitLabeledValue(UFitProfileAdministrationCopy.status, value: profile.status.label)
                    if let message {
                        UFitNotice(message: message, kind: messageIsError ? .error : .information)
                    }
                    if isLoading { UFitLoading() }
                    if let decision {
                        Text(UFitProfileAdministrationCopy.consequence(decision)).font(UFitTypography.callout)
                        if requiresReferenceReload || !profile.allows(decision) {
                            UFitButton(UFitProfileAdministrationCopy.reload, action: onRefresh).ufitButtonStyle(.secondary).disabled(isLoading || isSaving)
                        }
                        UFitMultilineField(label: UFitUserAdministrationCopy.reason, text: $reason, error: reasonError).disabled(isSaving)
                        UFitButton(UFitProfileAdministrationCopy.cancel, action: onCancel).ufitButtonStyle(.secondary).disabled(isSaving)
                    } else {
                        VStack(alignment: .leading, spacing: UFitSpace.md) {
                            UFitEditorialHeading(title: UFitProfileAdministrationCopy.change, editorial: false)
                            if decisions.isEmpty { Text(UFitProfileAdministrationCopy.noActions).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                            ForEach(decisions) { status in
                                UFitButton(UFitProfileAdministrationCopy.action(status), role: status == .suspended ? .destructive : nil) { onChoose(status) }
                                    .ufitButtonStyle(.secondary).disabled(isLoading || requiresReferenceReload)
                            }
                            if requiresReferenceReload {
                                UFitButton(UFitUserAdministrationCopy.retry, action: onRefresh).ufitButtonStyle(.secondary).disabled(isLoading)
                            }
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: UFitSpace.md) {
                            UFitEditorialHeading(title: UFitProfileAdministrationCopy.history, editorial: false)
                            if history.isEmpty {
                                if hasLoadedHistory && !isLoading && !messageIsError { Text(UFitProfileAdministrationCopy.noHistory).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                            } else {
                                ForEach(history) { change in
                                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                        Text(change.toStatus.label).font(UFitTypography.headline)
                                        Text(change.createdAt.value.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(UFitProfileAdministrationCopy.locale)))
                                            .font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                                        Text(change.reason).font(UFitTypography.body)
                                        Divider()
                                    }
                                }
                                if hasMore { UFitButton(UFitUserAdministrationCopy.more, action: onMore).ufitButtonStyle(.secondary).disabled(isLoading) }
                            }
                        }
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
                .ufitRefreshable(isEnabled: decision == nil && !isLoading && !isSaving, title: UFitUserAdministrationCopy.refresh) { onRefresh() }
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if let decision {
                UFitActionButton(title: UFitProfileAdministrationCopy.action(decision), kind: decision == .suspended ? .destructive : .primary,
                    isBusy: isSaving, disabled: !canSave, action: onSave).padding(UFitSpace.md).background(Color.ufitCanvas)
                    .overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline) }
            }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
}
