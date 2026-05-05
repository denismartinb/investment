import Foundation

enum DashboardDateFormatter {
    static let iso: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let longEs: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    static let axisEs: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM yy"
        return formatter
    }()

    static func parseISO(_ value: String) -> Date {
        iso.date(from: value) ?? .distantPast
    }

    static func display(_ value: String) -> String {
        guard let date = iso.date(from: value) else { return value }
        return longEs.string(from: date)
    }

    static func axisLabel(_ date: Date) -> String {
        axisEs.string(from: date)
    }

    static func wrappedLabel(_ value: String) -> String {
        guard let lastSpace = value.lastIndex(of: " ") else { return value }
        let first = value[..<lastSpace]
        let second = value[value.index(after: lastSpace)...]
        return "\(first)\n\(second)"
    }
}
