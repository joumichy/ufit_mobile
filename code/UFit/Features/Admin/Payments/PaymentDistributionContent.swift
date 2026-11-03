import SwiftUI

struct UFitDistributionBrandsContent: View {
    @Bindable var store: UFitDistributionBrandsStore
    let onBack: () -> Void; let onOpen: (String) -> Void
    private typealias Copy = UFitDistributionCopy
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                UFitButton { Task { await store.refresh() } } label: { UFitIcon(systemName: Copy.refreshIcon) }
                    .accessibilityLabel(Copy.refresh).disabled(store.isLoading)
            }
            UFitSearchField(query: $store.search, prompt: Copy.search).padding(.horizontal, UFitSpace.page).padding(.vertical, UFitSpace.md)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.lg) {
                    if let message = store.message {
                        UFitNotice(message: message, kind: .error)
                        if !store.invalidSearch { UFitActionButton(title: Copy.retry, kind: .secondary) { Task { await store.retry() } } }
                    }
                    if store.rows.isEmpty {
                        if store.isLoading || (!store.hasLoaded && store.message == nil) { UFitLoading(Copy.loadingBrands).frame(maxWidth: .infinity) }
                        else if store.message == nil {
                            UFitEmptyState(title: Copy.empty, symbol: Copy.icon)
                            if !store.search.isEmpty { UFitActionButton(title: Copy.clear, kind: .secondary) { store.search = String() } }
                        }
                    }
                    LazyVStack(spacing: .zero) {
                        ForEach(store.rows) { row in
                            UFitButton { onOpen(row.id) } label: {
                                HStack(alignment: .top, spacing: UFitSpace.md) {
                                    VStack(alignment: .leading, spacing: UFitSpace.xs) {
                                        Text(row.brand.name).font(UFitTypography.headline).fixedSize(horizontal: false, vertical: true)
                                        if let current = row.current {
                                            Text(current.rateLabel + Copy.separator + current.statusLabel).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                                        } else { Text(Copy.unset).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText) }
                                    }
                                    Spacer(minLength: UFitSpace.sm)
                                    UFitIcon(systemName: Copy.nextIcon).accessibilityHidden(true)
                                }.frame(minHeight: UFitControlSize.touch, alignment: .leading).padding(.vertical, UFitSpace.md).contentShape(Rectangle())
                            }.ufitButtonStyle(.text)
                            Divider()
                        }
                    }
                    if !store.rows.isEmpty && store.isLoading { UFitLoading().frame(maxWidth: .infinity) }
                    if store.nextCursor != nil && store.message == nil {
                        UFitActionButton(title: Copy.more, kind: .secondary, disabled: store.isLoading) { Task { await store.load(reset: false) } }
                    }
                }.padding(.horizontal, UFitSpace.page).padding(.bottom, UFitSpace.xl)
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .task { if !store.hasLoaded { await store.load() } }
            .onChange(of: store.search) { _, _ in Task { await store.searchChanged() } }
            .onDisappear { store.cancelLoading() }
    }
}

struct UFitDistributionDetailContent: View {
    let store: UFitDistributionDetailStore
    let notice: String?
    let onBack: () -> Void; let onEdit: () -> Void; let onHistory: () -> Void
    private typealias Copy = UFitDistributionCopy
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                UFitButton { Task { await store.refresh() } } label: { UFitIcon(systemName: Copy.refreshIcon) }
                    .accessibilityLabel(Copy.refresh).disabled(store.isLoading)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xxl) {
                    if let notice, store.document != nil, store.message == nil, !store.isLoading {
                        UFitNotice(message: notice, kind: .information)
                    }
                    if let message = store.message {
                        UFitNotice(message: message, kind: .error)
                        UFitActionButton(title: Copy.retry, kind: .secondary) { Task { await store.refresh() } }
                    }
                    if let document = store.document {
                        VStack(alignment: .leading, spacing: UFitSpace.xs) {
                            Text(document.brand.name).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                            Text(document.brand.status.label).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        }
                        if let policy = document.current {
                            UFitDistributionPolicySummary(policy: policy)
                            UFitActionButton(title: Copy.edit, disabled: !store.canEdit, action: onEdit)
                            UFitExperienceActionRow(title: Copy.history, systemImage: Copy.historyIcon, action: onHistory)
                        } else {
                            UFitEmptyState(title: Copy.emptyTitle, symbol: Copy.icon)
                            UFitActionButton(title: Copy.configure, disabled: !store.canEdit, action: onEdit)
                        }
                        Text(Copy.consulted(document.asOf)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    } else if store.message == nil { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .task { if store.document == nil { await store.load() } }.onDisappear { store.cancelLoading() }
    }
}
struct UFitDistributionPolicySummary: View {
    let policy: UFitDistributionRevision
    private typealias Copy = UFitDistributionCopy
    var body: some View {
        VStack(alignment: .leading, spacing: UFitSpace.lg) {
            HStack { Text(Copy.platformShare).font(UFitTypography.callout); Spacer(); Text(policy.statusLabel).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
            Text(policy.rateLabel).font(UFitTypography.largeTitle.weight(.medium)).monospacedDigit()
            Text(Copy.basis).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            Divider()
            UFitLabeledValue(Copy.feeBearer, value: policy.feeBearer.label).font(UFitTypography.body)
            Text(policy.feeBearer == .brand ? Copy.brandCost : Copy.platformCost).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
            Text(Copy.creatorScope).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
        }
    }
}
struct UFitDistributionHistoryContent: View {
    let store: UFitDistributionHistoryStore
    let onBack: () -> Void
    private typealias Copy = UFitDistributionCopy
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.history, onBack: onBack) {
                UFitButton { Task { store.cancelLoading(); await store.load() } } label: { UFitIcon(systemName: Copy.refreshIcon) }
                    .accessibilityLabel(Copy.refresh).disabled(store.isLoading)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    if let name = store.detail.document?.brand.name { Text(name).font(UFitTypography.title2) }
                    if let message = store.message {
                        UFitNotice(message: message, kind: .error)
                        UFitActionButton(title: Copy.retry, kind: .secondary) { Task { await store.retry() } }
                    }
                    if store.rows.isEmpty && store.message == nil {
                        if store.isLoading || !store.hasLoaded { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                        else { UFitEmptyState(title: Copy.noHistory, symbol: Copy.historyIcon) }
                    }
                    ForEach(store.rows) { policy in
                        VStack(alignment: .leading, spacing: UFitSpace.sm) {
                            HStack {
                                Text(Copy.revision(policy.revision)).font(UFitTypography.headline)
                                Spacer()
                                if policy.supersededAt == nil { Text(Copy.currentVersion).font(UFitTypography.caption) }
                            }
                            Text(policy.rateLabel).font(UFitTypography.title2).monospacedDigit()
                            if let retired = policy.supersededAt { Text(Copy.replaced(retired)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                            else { Text(policy.statusLabel).font(UFitTypography.caption) }
                            UFitLabeledValue(Copy.feeBearer, value: policy.feeBearer.label).font(UFitTypography.callout)
                            Text(Copy.versionDate(policy.createdAt)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                            Text(policy.reason).font(UFitTypography.callout).fixedSize(horizontal: false, vertical: true)
                            Divider().padding(.top, UFitSpace.sm)
                        }
                    }
                    if !store.rows.isEmpty && store.isLoading { UFitLoading().frame(maxWidth: .infinity) }
                    if store.nextCursor != nil && store.message == nil {
                        UFitActionButton(title: Copy.more, kind: .secondary, disabled: store.isLoading) { Task { await store.load(reset: false) } }
                    }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .task { if !store.hasLoaded { await store.load() } }.onDisappear { store.cancelLoading() }
    }
}
