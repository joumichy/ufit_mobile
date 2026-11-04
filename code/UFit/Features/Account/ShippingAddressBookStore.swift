import Foundation
import Observation

@MainActor @Observable
final class UFitShippingAddressBookStore {
    private(set) var items: [UFitShippingAddressItem] = []
    private(set) var defaultAddress: UFitShippingAddressItem?
    private(set) var defaultID: String?
    private(set) var version: Int?
    private(set) var nextCursor: String?
    private(set) var countries: [UFitCountry] = []
    private(set) var isLoading = false
    private(set) var isLoadingCountries = false
    private(set) var busyID: String?
    private(set) var isResuming = false
    private(set) var loadError: String?
    private(set) var loadFailedAtEnd = false
    private(set) var countryError: String?
    private(set) var message: String?
    private(set) var pending: UFitShippingAddressCommand?
    private(set) var storageFailed = false
    private(set) var needsRefresh = false
    private enum LoadCopy {
        static let pageFailure = String(localized: "Les adresses suivantes n’ont pas pu être chargées. Réessayez.")
        static let bookFailure = String(localized: "Vos adresses n’ont pas pu être chargées. Réessayez.")
    }
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var loadGeneration = UUID()
    @ObservationIgnored private var ownerID: String?
    init(session: UFitSessionStore) { self.session = session }
    var hasLoaded: Bool { version != nil }
    private func current(_ userID: String, _ request: UUID) -> Bool { session.user?.id == userID && generation == request }
    private func journal(_ userID: String) -> UFitShippingAddressJournal { .init(userID: userID, endpoint: session.api.configuration.baseURL) }
    func reset() {
        generation = UUID(); loadGeneration = UUID(); ownerID = nil; items = []; defaultAddress = nil; defaultID = nil; version = nil; nextCursor = nil
        countries = []; isLoading = false; isLoadingCountries = false; busyID = nil; isResuming = false; loadError = nil; loadFailedAtEnd = false; countryError = nil
        message = nil; pending = nil; storageFailed = false; needsRefresh = false
    }
    func load(more: Bool = false) async {
        guard let userID = session.user?.id else { reset(); return }
        if ownerID != userID { reset(); ownerID = userID }
        guard !isLoading, !more || nextCursor != nil else { return }
        let request = generation, cursor = more ? nextCursor : nil
        let loadRequest = UUID(); loadGeneration = loadRequest
        let ownsLoad = { self.current(userID, request) && self.loadGeneration == loadRequest }
        isLoading = true; loadError = nil; loadFailedAtEnd = false
        defer { if ownsLoad() { isLoading = false } }
        do {
            let page = try await session.api.shippingAddresses(userID: userID, cursor: cursor)
            guard ownsLoad() else { return }
            guard page.version >= (version ?? .zero) else { return }
            if more {
                guard page.version == version, page.defaultAddressId == defaultID,
                      Set(items.map(\.id)).isDisjoint(with: page.items.map(\.id)) else { throw UFitShippingAddressFailure.document }
            }
            items = more ? items + page.items : page.items
            if needsRefresh { message = nil }
            needsRefresh = false
            version = page.version; defaultID = page.defaultAddressId; nextCursor = page.nextCursor; loadError = nil
            defaultAddress = items.first { $0.id == defaultID }
            if let defaultID, defaultAddress == nil {
                let item = try await session.api.shippingAddress(userID: userID, id: defaultID)
                guard ownsLoad() else { return }
                defaultAddress = item
            }
            do { pending = try journal(userID).read(); storageFailed = false }
            catch { storageFailed = true; message = UFitShippingAddressFailure.storage.localizedDescription; return }
            if let pending {
                if let receipt = try await session.api.shippingAddressReceipt(pending) {
                    guard ownsLoad() else { return }
                    try journal(userID).clear(); self.pending = nil
                    // Receipt and list can straddle a commit: reload the authoritative book before using its version.
                    let latest = try await session.api.shippingAddresses(userID: userID)
                    guard ownsLoad() else { return }
                    guard latest.version >= receipt.version else { throw UFitShippingAddressFailure.document }
                    items = latest.items; version = latest.version; defaultID = latest.defaultAddressId; nextCursor = latest.nextCursor
                    defaultAddress = items.first { $0.id == defaultID }
                    if let defaultID, defaultAddress == nil {
                        let item = try await session.api.shippingAddress(userID: userID, id: defaultID)
                        guard ownsLoad() else { return }; defaultAddress = item
                    }
                    message = String(localized: "Votre modification a été enregistrée.")
                } else { message = String(localized: "Une modification reste à reprendre. Elle sera envoyée avec la même référence.") }
            }
        } catch {
            guard ownsLoad() else { return }
            loadFailedAtEnd = more
            if more, Self.code(error) == UFitShippingAddressesHTTP.changed {
                nextCursor = nil; loadError = String(localized: "Le carnet a changé. Actualisez pour retrouver vos adresses.")
            } else { loadError = more ? LoadCopy.pageFailure : LoadCopy.bookFailure }
            if case UFitAPIError.requestFailed(let status, _, _) = error, status == 401 || status == 403 || status == 404 {
                items = []; defaultAddress = nil; defaultID = nil; version = nil; nextCursor = nil
            }
        }
    }
    func loadCountries() async {
        guard let userID = session.user?.id else { return }
        if ownerID != userID { reset(); ownerID = userID }
        guard !isLoadingCountries else { return }
        let request = generation; isLoadingCountries = true; countryError = nil
        defer { if current(userID, request) { isLoadingCountries = false } }
        do {
            let result = try await session.api.shippingCountries()
            guard current(userID, request) else { return }; countries = result; countryError = nil
        } catch {
            guard current(userID, request) else { return }
            countryError = String(localized: "Les pays disponibles n’ont pas pu être chargés. Réessayez.")
        }
    }
    func save(address: UFitShippingAddress, id: String?, makeDefault: Bool) async -> Bool {
        let value = address.normalized
        do { try value.validate() } catch { message = error.localizedDescription; return false }
        guard countries.contains(where: { $0.id == value.country }) else {
            message = String(localized: "Choisissez un pays disponible avant d’enregistrer l’adresse."); return false
        }
        return await apply(action: .save, id: id ?? UUID().uuidString.lowercased(), address: value, makeDefault: makeDefault)
    }
    func beginEditing() { if pending == nil { message = nil } }
    func remove(_ id: String) async { _ = await apply(action: .delete, id: id) }
    func setDefault(_ id: String?) async { _ = await apply(action: .setDefault, id: id) }
    private func apply(action: UFitShippingAddressInput.Action, id: String?, address: UFitShippingAddress? = nil, makeDefault: Bool? = nil) async -> Bool {
        guard let userID = session.user?.id, ownerID == userID, let version else { return false }
        guard !isLoading else { message = String(localized: "Attendez la fin de l’actualisation du carnet."); return false }
        guard busyID == nil, pending == nil, !storageFailed else {
            message = String(localized: "Terminez la modification en cours avant d’en commencer une autre."); return false
        }
        let command = UFitShippingAddressCommand(userID: userID, requestID: UUID().uuidString.lowercased(),
            input: .init(expectedVersion: version, action: action, addressId: id, shippingAddress: address, makeDefault: makeDefault))
        do { try journal(userID).write(command); pending = command }
        catch { storageFailed = true; message = UFitShippingAddressFailure.storage.localizedDescription; return false }
        return await send(command)
    }
    func resume() async -> Bool {
        guard let pending, busyID == nil else { return false }
        let request = generation
        isResuming = true
        defer { if generation == request { isResuming = false } }
        return await send(pending)
    }
    private func send(_ command: UFitShippingAddressCommand) async -> Bool {
        let request = generation, userID = command.userID
        guard current(userID, request), busyID == nil else { return false }
        busyID = command.input.addressId ?? command.requestID; message = nil
        defer { if current(userID, request) { busyID = nil } }
        do {
            let receipt: UFitShippingAddressReceipt
            if let known = try await session.api.shippingAddressReceipt(command) { receipt = known }
            else {
                guard current(userID, request) else { return false }
                receipt = try await session.api.changeShippingAddress(command)
            }
            guard current(userID, request) else { return false }
            version = max(version ?? .zero, receipt.version)
            try journal(userID).clear(); pending = nil; storageFailed = false
            loadGeneration = UUID(); isLoading = false
            await load()
            guard current(userID, request) else { return false }
            message = String(localized: "Votre carnet a été mis à jour.")
            return true
        } catch {
            guard current(userID, request) else { return false }
            let code = Self.code(error)
            if [UFitShippingAddressesHTTP.changed, UFitShippingAddressesHTTP.invalid, UFitShippingAddressesHTTP.missing,
                UFitShippingAddressesHTTP.unavailable, UFitShippingAddressesHTTP.reused].contains(code) {
                do { try journal(userID).clear(); pending = nil } catch { storageFailed = true }
                message = code == UFitShippingAddressesHTTP.changed
                    ? String(localized: "Le carnet a été modifié ailleurs. Actualisez-le ; votre saisie est conservée.")
                    : String(localized: "Cette modification n’a pas été acceptée. Actualisez le carnet pour réessayer.")
                needsRefresh = true
            } else { message = String(localized: "L’enregistrement n’a pas pu être confirmé. Reprenez la modification avant d’en créer une autre.") }
            return false
        }
    }
    private static func code(_ error: Error) -> String? {
        if case UFitAPIError.requestFailed(_, _, let code) = error { return code }; return nil
    }
}
