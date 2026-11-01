import Foundation

enum UFitDecimalInput {
    static let maximumInteger = 2147483647
    private static let minimum = 0
    private static let decimalRadix = 10
    private static let comma = ","; private static let point = "."; private static let zeroDigit = "0"
    private static let amountPattern = #"^[0-9]+(?:[.,][0-9]+)?$"#
    private static let integerPattern = #"^[0-9]+$"#
    private static let firstComponent = 0; private static let fractionalComponent = 1; private static let minimumComponents = 1
    static func integer(_ text: String) -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: integerPattern, options: .regularExpression) != nil,
              let amount = Int(value), (minimum...maximumInteger).contains(amount) else { return nil }
        return amount
    }
    static func scaledAmount(_ text: String, fractionalDigits: Int, maximum: Int = UFitDecimalInput.maximumInteger) -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard fractionalDigits >= minimum, maximum >= minimum, value.range(of: amountPattern, options: .regularExpression) != nil else { return nil }
        let parts = value.replacingOccurrences(of: comma, with: point).components(separatedBy: point)
        let fraction = parts.count > minimumComponents ? parts[fractionalComponent] : String()
        guard fraction.count <= fractionalDigits, let whole = Int(parts[firstComponent]) else { return nil }
        var amount = whole
        for digit in fraction + String(repeating: zeroDigit, count: fractionalDigits - fraction.count) {
            guard let digitValue = digit.wholeNumberValue else { return nil }
            let product = amount.multipliedReportingOverflow(by: decimalRadix)
            let sum = product.partialValue.addingReportingOverflow(digitValue)
            guard !product.overflow, !sum.overflow, sum.partialValue <= maximum else { return nil }
            amount = sum.partialValue
        }
        return (minimum...maximum).contains(amount) ? amount : nil
    }
    static func text(_ amount: Int, fractionalDigits: Int) -> String {
        guard fractionalDigits > minimum else { return String(amount) }
        let digits = String(amount)
        let padding = max(minimum, fractionalDigits + minimumComponents - digits.count)
        let padded = String(repeating: zeroDigit, count: padding) + digits
        let split = padded.index(padded.endIndex, offsetBy: -fractionalDigits)
        return String(padded[..<split]) + comma + String(padded[split...])
    }
}
