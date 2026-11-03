import Foundation

enum UFitDistributionBoundaryFailure: LocalizedError {
    case document
    var errorDescription: String? { UFitDistributionCopy.invalid }
}
struct UFitDistributionBrand: Decodable, Identifiable {
    let id: String; let name: String; let status: UFitProfileStatus
    func validate() throws {
        guard UFitDistributionHTTP.validID(id), !UFitServerTextInput.trimmed(name).isEmpty else { throw UFitDistributionBoundaryFailure.document }
    }
}
enum UFitDistributionFeeBearer: String, Decodable, Encodable, CaseIterable, Identifiable {
    case brand, platform
    var id: Self { self }
    var label: String { self == .brand ? UFitDistributionCopy.brandBearer : UFitDistributionCopy.platformBearer }
}
struct UFitDistributionRevision: Decodable, Identifiable {
    let id: String; let brandId: String; let requestId: String; let revision: Int
    @UFitRequiredNullable var previousId: String?
    let platformRateBps: Int; let feeBearer: UFitDistributionFeeBearer; let active: Bool; let reason: String
    let createdAt: UFitTimestamp
    @UFitRequiredNullable var supersededAt: UFitTimestamp?
    var rateLabel: String { UFitDistributionCopy.percent(platformRateBps) }
    var statusLabel: String { active ? UFitDistributionCopy.active : UFitDistributionCopy.inactive }
    func validate(brandID: String) throws {
        guard [id, brandId, requestId].allSatisfy(UFitDistributionHTTP.validID), brandId == brandID,
              (UFitDistributionHTTP.firstRevision...UFitDistributionHTTP.maximumRevision).contains(revision),
              (revision == UFitDistributionHTTP.firstRevision) == (previousId == nil),
              previousId.map({ UFitDistributionHTTP.validID($0) && $0 != id }) ?? true,
              (.zero...UFitDistributionHTTP.basisPoints).contains(platformRateBps),
              !UFitServerTextInput.trimmed(reason).isEmpty, reason.utf16.count <= UFitDistributionHTTP.reasonMaximum,
              supersededAt.map({ $0.value >= createdAt.value }) ?? true else { throw UFitDistributionBoundaryFailure.document }
    }
}
struct UFitDistributionDocument: Decodable {
    let brand: UFitDistributionBrand
    @UFitRequiredNullable var current: UFitDistributionRevision?
    let asOf: UFitTimestamp
    func validate(brandID: String) throws {
        try brand.validate()
        guard brand.id == brandID, current?.supersededAt == nil else { throw UFitDistributionBoundaryFailure.document }
        try current?.validate(brandID: brandID)
    }
}
struct UFitDistributionBrandRow: Decodable, Identifiable {
    var brand: UFitDistributionBrand
    @UFitRequiredNullable var current: UFitDistributionRevision?
    var id: String { brand.id }
}
struct UFitDistributionBrandPage: Decodable {
    let items: [UFitDistributionBrandRow]
    @UFitRequiredNullable var nextCursor: String?
    func validate(after cursor: String?) throws {
        guard items.count <= UFitDistributionHTTP.pageSize, Set(items.map(\.id)).count == items.count,
              nextCursor == nil || items.count == UFitDistributionHTTP.pageSize && nextCursor == items.last?.id else { throw UFitDistributionBoundaryFailure.document }
        var previous = cursor
        for row in items {
            try row.brand.validate(); try row.current?.validate(brandID: row.id)
            guard row.current?.supersededAt == nil, previous.map({ row.id > $0 }) ?? true else { throw UFitDistributionBoundaryFailure.document }
            previous = row.id
        }
    }
}
struct UFitDistributionHistoryPage: Decodable {
    let brandId: String; let items: [UFitDistributionRevision]
    @UFitRequiredNullable var nextCursor: String?
    func validate(brandID: String, after revision: Int?) throws {
        guard brandId == brandID, items.count <= UFitDistributionHTTP.pageSize,
              Set(items.map(\.id)).count == items.count, Set(items.map(\.requestId)).count == items.count,
              nextCursor == nil || items.count == UFitDistributionHTTP.pageSize && nextCursor == items.last?.id else { throw UFitDistributionBoundaryFailure.document }
        var previous = revision
        for item in items {
            try item.validate(brandID: brandID)
            guard previous.map({ item.revision == $0 - UFitDistributionHTTP.firstRevision }) ?? true else { throw UFitDistributionBoundaryFailure.document }
            previous = item.revision
        }
    }
}
struct UFitDistributionChangeBody: Encodable {
    let requestId: String; let expectedRevision: Int; let platformRateBps: Int
    let feeBearer: UFitDistributionFeeBearer; let active: Bool; let reason: String
    func validate(previousID: String?) throws {
        guard UFitDistributionHTTP.validID(requestId), (.zero..<UFitDistributionHTTP.maximumRevision).contains(expectedRevision),
              (expectedRevision == .zero) == (previousID == nil), previousID.map(UFitDistributionHTTP.validID) ?? true,
              (.zero...UFitDistributionHTTP.basisPoints).contains(platformRateBps),
              reason == UFitServerTextInput.trimmed(reason), !reason.isEmpty,
              reason.utf16.count <= UFitDistributionHTTP.reasonMaximum else { throw UFitDistributionBoundaryFailure.document }
    }
}
struct UFitDistributionChangeResult: Decodable {
    let receipt: UFitDistributionRevision; let document: UFitDistributionDocument
    func validate(brandID: String, body: UFitDistributionChangeBody, previousID: String?) throws {
        try receipt.validate(brandID: brandID); try document.validate(brandID: brandID)
        guard receipt.requestId == body.requestId, receipt.revision == body.expectedRevision + UFitDistributionHTTP.firstRevision,
              receipt.previousId == previousID, receipt.platformRateBps == body.platformRateBps,
              receipt.feeBearer == body.feeBearer, receipt.active == body.active, receipt.reason == body.reason,
              let current = document.current, current.revision >= receipt.revision else { throw UFitDistributionBoundaryFailure.document }
    }
}
