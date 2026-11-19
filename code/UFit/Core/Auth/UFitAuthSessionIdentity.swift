import Foundation
import Supabase

/// Distinguishes sessions held by the SDK; the backend still authorizes every request.
struct UFitAuthSessionIdentity: Equatable {
    let subject: UUID
    let sessionID: String?
    private enum JWT {
        static let separator: Character = ".", segments = 3, payload = 1, word = 4
        static let urlPlus = "-", plus = "+", urlSlash = "_", slash = "/", padding = "="
    }
    private struct Claims: Decodable {
        let sub: UUID
        let sessionID: String?
        enum CodingKeys: String, CodingKey { case sub; case sessionID = "session_id" }
    }
    init?(_ session: Session?) {
        guard let session else { return nil }
        subject = session.user.id
        let segments = session.accessToken.split(separator: JWT.separator, omittingEmptySubsequences: false)
        guard segments.count == JWT.segments else { sessionID = nil; return }
        var payload = String(segments[JWT.payload]).replacingOccurrences(of: JWT.urlPlus, with: JWT.plus).replacingOccurrences(of: JWT.urlSlash, with: JWT.slash)
        payload += String(repeating: JWT.padding, count: (JWT.word - payload.count % JWT.word) % JWT.word)
        guard let data = Data(base64Encoded: payload), let claims = try? JSONDecoder().decode(Claims.self, from: data), claims.sub == session.user.id else { sessionID = nil; return }
        sessionID = claims.sessionID.flatMap { UFitInstallationHTTP.identifier($0) ? $0 : nil }
    }
}
