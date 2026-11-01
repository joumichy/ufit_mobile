import Foundation

@propertyWrapper struct UFitRequiredNullable<Value: Decodable>: Decodable {
    var wrappedValue: Value?
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        wrappedValue = value.decodeNil() ? nil : try value.decode(Value.self)
    }
}
