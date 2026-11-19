import Foundation
import Observation

@MainActor @Observable
final class UFitPublicationCalendarStore {
    let collection: UFitManagedOutfitsStore
    let timeZone: TimeZone
    var month: Date { didSet { collection.calendarMonth = month } }
    var selectedDay: Date { didSet { collection.calendarSelectedDay = selectedDay } }
    private var cached: [UFitManagedOutfit] = []
    private var revoked = false
    var canRead: Bool {
        guard collection.isCurrentAccount, let user = collection.session.user, let scope = collection.scope else { return false }
        return scope.kind == .creator ? user.isCreator : user.isBrandMember
    }
    var outfits: [UFitManagedOutfit] { canRead && !revoked ? cached : [] }
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var isLoadingMore = false
    private(set) var nextCursor: String?
    private(set) var busyIDs = Set<String>()
    private enum Recovery { case refresh, more, detail(String) }
    private var recovery = Recovery.refresh
    private var failure: String?
    var message: String? { canRead ? failure : Copy.access }
    private enum Copy { static let access = String(localized: "Votre accès à cet espace a changé. Revenez aux espaces et actualisez.") }
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var openingID: String?
    @ObservationIgnored private var cursors = Set<String>()
    init(collection: UFitManagedOutfitsStore) {
        self.collection = collection; timeZone = .current
        month = collection.calendarMonth; selectedDay = collection.calendarSelectedDay
    }
    var calendar: Calendar { UFitPublicationCalendarMath.calendar(zone: timeZone) }
    var markedDays: Set<Int> {
        Set(outfits.compactMap { $0.scheduledFor.flatMap(UFitPublicationDate.parse).map { calendar.component(.day, from: $0) } })
    }
    var selectedOutfits: [UFitManagedOutfit] {
        outfits.filter { row in row.scheduledFor.flatMap(UFitPublicationDate.parse).map { calendar.isDate($0, inSameDayAs: selectedDay) } == true }
            .sorted { $0.scheduledFor! == $1.scheduledFor! ? $0.id < $1.id : $0.scheduledFor! < $1.scheduledFor! }
    }
    func moveMonth(_ value: Int) async {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        generation = UUID(); month = calendar.dateInterval(of: .month, for: next)!.start; selectedDay = month
        cached = []; hasLoaded = false; isLoading = false; isLoadingMore = false; nextCursor = nil; failure = nil; busyIDs = []; openingID = nil
        await load()
    }
    func load(more: Bool = false) async {
        guard canRead, let scope = collection.scope, !isLoading, !isLoadingMore,
              let interval = calendar.dateInterval(of: .month, for: month), !more || nextCursor != nil else { return }
        let cursor = more ? nextCursor : nil
        if !more { generation = UUID(); isLoading = true; busyIDs = []; openingID = nil } else { isLoadingMore = true }
        let request = generation; failure = nil
        defer { if request == generation { isLoading = false; isLoadingMore = false } }
        do {
            let page = try await collection.client.fetchPublicationCalendar(scope: scope, from: interval.start, until: interval.end, cursor: cursor)
            guard request == generation, canRead else { return }
            if more {
                guard let cursor, !cursors.contains(cursor), Set(outfits.map(\.id)).isDisjoint(with: page.items.map(\.id)) else { throw UFitOutfitContractError.page }
                cached.append(contentsOf: page.items); cursors.insert(cursor)
            } else { cached = page.items; cursors = [] }
            nextCursor = page.nextCursor; hasLoaded = true; revoked = false
        } catch { receive(error, request: request, recovery: more ? .more : .refresh) }
    }
    func open(_ id: String) async -> UFitManagedOutfitStore? {
        guard !busyIDs.contains(id), canRead else { return nil }
        let request = generation; busyIDs.insert(id); openingID = id; failure = nil
        defer { if request == generation { busyIDs.remove(id) } }
        do {
            let result = try await collection.client.fetchManagedOutfit(id: id, scope: collection.scope)
            guard request == generation, openingID == id, canRead else { return nil }
            return .init(document: result, collection: collection)
        } catch {
            if openingID == id { receive(error, request: request, recovery: .detail(id)) }
            return nil
        }
    }
    func retry() async -> UFitManagedOutfitStore? {
        switch recovery {
        case .refresh: await load()
        case .more: await load(more: true)
        case .detail(let id): return await open(id)
        }
        return nil
    }
    private func receive(_ error: Error, request: UUID, recovery: Recovery) {
        guard request == generation, canRead else { return }
        self.recovery = recovery
        if case UFitAPIError.requestFailed(UFitOutfitResponseStatus.forbidden, _, _) = error {
            cached = []; nextCursor = nil; hasLoaded = false; cursors = []; busyIDs = []; openingID = nil
            revoked = true; generation = UUID(); isLoading = false; isLoadingMore = false
            self.recovery = .refresh
        }
        failure = error.localizedDescription
    }
    func cancel() { generation = UUID(); isLoading = false; isLoadingMore = false; busyIDs = []; openingID = nil }
}
