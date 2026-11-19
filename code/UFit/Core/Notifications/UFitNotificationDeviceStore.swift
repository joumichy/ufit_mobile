import Foundation
import Observation
import UIKit
import UserNotifications

struct UFitNotificationAccountContext: Equatable { let userID: String, authSessionID: String }
@MainActor @Observable
final class UFitNotificationDeviceStore {
    private(set) var permission = UFitNotificationPermission.unknown
    private(set) var phase = UFitNotificationDevicePhase.idle
    private(set) var isRequestingPermission = false
    private(set) var isCheckingSettings = false
    private(set) var message: String?
    @ObservationIgnored private weak var session: UFitSessionStore?
    @ObservationIgnored private let vault = UFitInstallationKeychain()
    @ObservationIgnored private var identity: UFitInstallationIdentity?
    @ObservationIgnored private var storageFailed = false
    @ObservationIgnored private var token: String?
    @ObservationIgnored private var tokenEvent: UUID?
    @ObservationIgnored private var nativeRequestID: UUID?
    @ObservationIgnored private var confirmed: (event: UUID, registration: String)?
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var tokenWatch: Task<Void, Never>?
    @ObservationIgnored private var needsSync = false
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var settingsRequest = UUID()
    @ObservationIgnored private var appliedContext: UFitNotificationAccountContext?
    private enum Contract { static let environmentKey = "UFIT_APNS_ENVIRONMENT", tokenWait: Duration = .seconds(30) }
    init(session: UFitSessionStore) {
        self.session = session
        do { identity = try vault.read() } catch { storageFailed = true }
    }
    var isBusy: Bool { isCheckingSettings || isRequestingPermission || phase == .waitingForToken || phase == .linking }
    private var context: UFitNotificationAccountContext? { session?.notificationContext }
    func connect(_ delegate: UFitNotificationsDelegate) { delegate.device = self; Task { await refresh() } }
    func contextChanged() {
        if appliedContext != context { generation = UUID(); confirmed = nil; appliedContext = context }
        Task { await refresh() }
    }
    func prepareForAuthentication() {
        tokenWatch?.cancel(); nativeRequestID = nil; token = nil; tokenEvent = nil
        UIApplication.shared.unregisterForRemoteNotifications()
        do { try endBinding() }
        catch { UIApplication.shared.unregisterForRemoteNotifications(); registrationFailed() }
    }
    func endBinding() throws {
        if storageFailed { throw UFitInstallationFailure.storage }
        if var current = identity, let binding = current.binding {
            if !current.pendingDetachments.contains(binding.id) { current.pendingDetachments.append(binding.id) }
            current.binding = nil; try persist(current)
        }
        generation = UUID(); confirmed = nil; phase = .idle
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        requestSync()
    }
    func refresh() async {
        let request = UUID(); settingsRequest = request; isCheckingSettings = true
        defer { if settingsRequest == request { isCheckingSettings = false } }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settingsRequest == request else { return }
        switch settings.authorizationStatus {
        case .notDetermined: permission = .notAsked
        case .denied: permission = .denied
        case .authorized, .provisional, .ephemeral: permission = .allowed
        @unknown default: permission = .unknown
        }
        if permission != .allowed {
            tokenWatch?.cancel(); nativeRequestID = nil; token = nil; tokenEvent = nil; confirmed = nil
            UIApplication.shared.unregisterForRemoteNotifications()
            do { try endBinding() } catch { message = UFitNotificationDeviceCopy.unavailable }
            return
        }
        if context != nil && (token == nil || phase == .failed) && phase != .waitingForToken { requestToken() }
        requestSync()
    }
    func authorize() async {
        guard !isRequestingPermission, permission == .notAsked else { return }
        isRequestingPermission = true; message = nil
        defer { isRequestingPermission = false }
        do { _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]); await refresh() }
        catch { message = UFitNotificationDeviceCopy.unavailable }
    }
    func openSettings() async {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString), await UIApplication.shared.open(url) else {
            message = UFitNotificationDeviceCopy.settingsFailed; return
        }
    }
    func retry() async { message = nil; if storageFailed { do { identity = try vault.read(); storageFailed = false } catch {} }; await refresh() }
    private func requestToken() {
        phase = .waitingForToken; message = nil; nativeRequestID = UUID(); confirmed = nil
        let request = generation, nativeRequest = nativeRequestID
        UIApplication.shared.registerForRemoteNotifications()
        tokenWatch?.cancel(); tokenWatch = Task { [weak self] in
            do { try await Task.sleep(for: Contract.tokenWait) } catch { return }
            guard let self, generation == request, nativeRequestID == nativeRequest, phase == .waitingForToken else { return }
            registrationFailed()
        }
    }
    func received(token data: Data) {
        tokenWatch?.cancel()
        guard !data.isEmpty, permission == .allowed else { return }
        let value = UFitInstallationIdentity.hex(data)
        if let nativeRequestID { tokenEvent = nativeRequestID; confirmed = nil }
        else if token != value || tokenEvent == nil { tokenEvent = UUID(); confirmed = nil }
        nativeRequestID = nil; token = value; phase = .idle; requestSync()
    }
    func registrationFailed() {
        tokenWatch?.cancel(); nativeRequestID = nil; token = nil; tokenEvent = nil; confirmed = nil; phase = .failed; message = UFitNotificationDeviceCopy.unavailable
    }
    func mayPresent(id: String) async -> Bool {
        guard let expected = context, let session else { return false }
        do { _ = try await session.api.fetchNotification(id: id); return context == expected }
        catch { return false }
    }
    private func persist(_ value: UFitInstallationIdentity) throws { try vault.save(value); identity = value }
    private func requestSync() {
        needsSync = true
        guard work == nil else { return }
        work = Task { [weak self] in
            guard let self else { return }
            repeat { needsSync = false; await synchronize() } while needsSync
            work = nil
        }
    }
    private func synchronize() async {
        guard let session else { return }
        let attemptGeneration = generation
        do {
            if storageFailed { identity = try vault.read(); storageFailed = false }
            if identity?.binding != nil, !session.isRestoring, !session.isSignedIn { try endBinding() }
            while let current = identity, let target = current.pendingDetachments.first {
                try await session.api.detachInstallation(current, association: target)
                guard var latest = identity, latest.id == current.id else { throw UFitInstallationFailure.storage }
                latest.pendingDetachments.removeAll { $0 == target }; try persist(latest)
            }
            if permission == .allowed && !session.isRestoring && session.isSignedIn && session.user != nil && context == nil { throw UFitInstallationFailure.configuration }
            guard permission == .allowed, nativeRequestID == nil, let expected = context, let token, let event = tokenEvent else { return }
            let request = generation
            guard let raw = Bundle.main.object(forInfoDictionaryKey: Contract.environmentKey) as? String,
                  let environment = UFitPushEnvironment(rawValue: raw) else { throw UFitInstallationFailure.configuration }
            var current: UFitInstallationIdentity
            if let saved = identity { current = saved } else { current = try .create(); try persist(current) }
            if let binding = current.binding, binding.userID != expected.userID || binding.authSessionID != expected.authSessionID {
                try endBinding(); needsSync = true; return
            }
            if current.binding == nil {
                current.binding = .init(id: UUID().uuidString.lowercased(), userID: expected.userID, authSessionID: expected.authSessionID)
                try persist(current)
            }
            guard var binding = current.binding else { throw UFitInstallationFailure.storage }
            phase = .linking; message = nil
            var server = try await session.api.installation(current)
            guard generation == request, context == expected, tokenEvent == event else { return }
            if let pending = binding.operation, server.confirms(pending, association: binding.id) {
                binding.operation = nil; current.binding = binding; try persist(current)
                if pending.eventID == event && pending.tokenDigest == UFitInstallationIdentity.digest(token) {
                    confirmed = (event, pending.id); phase = .linked; return
                }
            }
            if let confirmed, confirmed.event == event, server.state == .registered, server.isCurrentAccount,
               server.associationId == binding.id, server.registrationId == confirmed.registration { phase = .linked; return }
            let digest = UFitInstallationIdentity.digest(token)
            let operation: UFitInstallationOperation
            if let pending = binding.operation, pending.tokenDigest == digest, pending.environment == environment { operation = pending }
            else {
                guard server.version < UFitInstallationHTTP.maximumVersion else { throw UFitInstallationFailure.document }
                operation = .init(id: UUID().uuidString.lowercased(), tokenDigest: digest, eventID: event, version: server.version, environment: environment)
                binding.operation = operation; current.binding = binding; try persist(current)
            }
            do { server = try await session.api.registerInstallation(current, binding: binding, operation: operation, token: token) }
            catch {
                guard generation == request, context == expected, tokenEvent == event else { return }
                if let reread = try? await session.api.installation(current) {
                    guard generation == request, context == expected, tokenEvent == event else { return }
                    if reread.confirms(operation, association: binding.id) { server = reread }
                    else {
                        if case .requestFailed(let status, _, let code) = error as? UFitAPIError, status == UFitInstallationHTTP.conflictStatus {
                            if code == UFitInstallationHTTP.closedCode { try endBinding() }
                            else { binding.operation = nil; current.binding = binding; try persist(current) }
                        }
                        throw error
                    }
                } else { throw error }
            }
            guard generation == request, context == expected, tokenEvent == event else { return }
            guard server.confirms(operation, association: binding.id) else { throw UFitInstallationFailure.document }
            binding.operation = nil; current.binding = binding; try persist(current)
            if operation.eventID != event { needsSync = true; return }
            confirmed = (event, operation.id); phase = .linked; message = nil
        } catch {
            if generation == attemptGeneration && permission == .allowed { phase = .failed; message = UFitNotificationDeviceCopy.unavailable }
        }
    }
}
