import Foundation
import SwiftUI

enum TickerMapper {
    static func symbol(from query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func isValid(_ query: String) -> Bool {
        let symbol = symbol(from: query)
        return symbol.range(of: "^[A-Z][A-Z0-9.-]{0,7}$", options: .regularExpression) != nil
    }
}

extension MarketSentiment {
    var tint: Color {
        switch self {
        case .bullish: return PerchPalette.gain
        case .neutral: return PerchPalette.accent
        case .bearish: return PerchPalette.loss
        }
    }
}

extension StockSector {
    var tint: Color {
        switch self {
        case .technology: return Color(red: 0.239, green: 0.482, blue: 0.878)
        case .consumer: return Color(red: 0.941, green: 0.706, blue: 0.161)
        case .communication: return Color(red: 0.239, green: 0.729, blue: 0.471)
        case .financials: return Color(red: 0.608, green: 0.365, blue: 0.898)
        case .unknown: return .gray
        case .healthcare: return Color(red: 0.125, green: 0.647, blue: 0.690)
        }
    }

    var iconName: String {
        switch self {
        case .technology: return "cpu"
        case .consumer: return "cart"
        case .communication: return "dot.radiowaves.left.and.right"
        case .financials: return "banknote"
        case .healthcare: return "cross.case"
        case .unknown: return "questionmark.circle"
        }
    }
}
