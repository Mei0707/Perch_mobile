import Foundation

extension DateFormatter {
    static let perchMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static let perchShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

extension Calendar {
    static let perch = Calendar(identifier: .gregorian)
}
