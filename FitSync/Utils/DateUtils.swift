import Foundation

enum DateUtils {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    static func startOfDay(_ date: Date = .now) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func endOfDay(_ date: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay(date))!
    }

    static func startOfYesterday() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: startOfDay())!
    }

    static func sleepWindowStart(for date: Date = .now) -> Date {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: startOfDay(date))!
        return cal.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday)!
    }

    static func sleepWindowEnd(for date: Date = .now) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 18, minute: 0, second: 0, of: startOfDay(date))!
    }

    static func durationString(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "无数据" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        }
        return "\(minutes)分钟"
    }

    static func fileTimestamp(from date: Date = .now) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HHmm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        return String(format: "%.1f KB", Double(bytes) / 1024)
    }
}
