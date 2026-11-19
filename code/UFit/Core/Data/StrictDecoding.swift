import Foundation

enum UFitStrictDecoding {
    private struct Key: CodingKey {
        let stringValue: String
        let intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    static func keys<K: CodingKey & CaseIterable>(_ decoder: Decoder, _ expected: K.Type, failure: any Error) throws {
        let actual = try decoder.container(keyedBy: Key.self)
        guard Set(actual.allKeys.map(\.stringValue)) == Set(expected.allCases.map(\.stringValue)) else { throw failure }
    }
}
