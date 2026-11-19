import Foundation
import Observation

@MainActor @Observable
final class UFitAdminActivityStore {
    private(set) var activity: UFitAdminActivity?
    private(set) var refundRecoveryCount: Int?
    private(set) var isLoading = false
    private(set) var message: String?
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private var generation = UUID()
    private enum HTTP { static let forbidden = 403 }
    init(session: UFitSessionStore) { self.session = session }
    func reset() { cancelLoading(); activity = nil; refundRecoveryCount = nil; message = nil }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func load() async {
        guard !isLoading, let userID = session.user?.id, session.user?.canAdminister == true else { return }
        let request = generation
        isLoading = true; activity = nil; refundRecoveryCount = nil; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            async let moderation = session.api.fetchAdminActivity()
            async let refunds = session.api.fetchRefundRecoveries(limit: UFitRefundRecoveryHTTP.countLimit)
            let (value, recoveries) = try await (moderation, refunds)
            guard generation == request, session.user?.id == userID, session.user?.canAdminister == true else { return }
            activity = value; refundRecoveryCount = recoveries.totalCount
        } catch {
            guard generation == request, session.user?.id == userID else { return }
            message = error.localizedDescription
            if case UFitAPIError.requestFailed(let status, _, _) = error, status == HTTP.forbidden {
                await session.reloadProfile()
            }
        }
    }
}
