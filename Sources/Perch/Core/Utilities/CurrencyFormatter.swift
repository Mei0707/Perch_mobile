import Foundation

enum CurrencyFormatter {
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func dollars(_ amount: Decimal) -> String {
        shared.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    static func compactDollars(_ amount: Decimal) -> String {
        let value = (amount as NSDecimalNumber).doubleValue
        if abs(value) >= 1_000 {
            return shared.string(from: NSNumber(value: value / 1_000)).map { "\($0)K" } ?? "$0K"
        }
        return dollars(amount)
    }
}
