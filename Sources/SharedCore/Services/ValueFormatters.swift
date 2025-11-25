import Foundation

/// Shared formatters and utilities to avoid repeated allocations
public enum ValueFormatters {

    // MARK: - Cached Formatters

    public static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    public static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    public static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "'"
        return formatter
    }()

    // MARK: - Value Display

    /// Formats a ParquetValue for display in a table cell
    public static func displayString(for value: ParquetValue, maxDecimals: Int = 6) -> String {
        switch value {
        case .null:
            return "NULL"
        case .bool(let b):
            return b ? "true" : "false"
        case .int(let i):
            return String(i)
        case .float(let f):
            if f.isNaN { return "NaN" }
            if f.isInfinite { return f > 0 ? "Inf" : "-Inf" }
            // Use appropriate precision based on magnitude
            if abs(f) >= 1e10 || (abs(f) < 1e-4 && f != 0) {
                return String(format: "%.\(maxDecimals)g", f)
            }
            // Remove trailing zeros
            let formatted = String(format: "%.\(maxDecimals)f", f)
            return trimTrailingZeros(formatted)
        case .string(let s):
            return s
        case .binary(let data):
            return "<\(formatBytes(data.count))>"
        case .date(let d):
            return shortDateFormatter.string(from: d)
        case .timestamp(let t):
            return shortDateTimeFormatter.string(from: t)
        }
    }

    /// Formats a number with thousands separators
    public static func formatNumber(_ num: Int) -> String {
        return numberFormatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }

    /// Formats bytes into human-readable form
    public static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) bytes" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        let gb = mb / 1024
        return String(format: "%.1f GB", gb)
    }

    private static func trimTrailingZeros(_ str: String) -> String {
        var result = str
        while result.hasSuffix("0") && result.contains(".") {
            result.removeLast()
        }
        if result.hasSuffix(".") {
            result.removeLast()
        }
        return result
    }

    // MARK: - Value Search/Filter

    /// Checks if a ParquetValue contains the search text (case-insensitive)
    public static func valueContains(_ value: ParquetValue, searchText: String) -> Bool {
        let search = searchText.lowercased()

        switch value {
        case .null:
            return "null".contains(search)
        case .bool(let b):
            return (b ? "true" : "false").contains(search)
        case .int(let i):
            return String(i).contains(search)
        case .float(let f):
            if f.isNaN { return "nan".contains(search) }
            if f.isInfinite { return "inf".contains(search) || "infinity".contains(search) }
            return String(f).contains(search)
        case .string(let s):
            return s.lowercased().contains(search)
        case .binary:
            return false
        case .date(let d):
            return shortDateFormatter.string(from: d).lowercased().contains(search)
        case .timestamp(let t):
            return shortDateTimeFormatter.string(from: t).lowercased().contains(search)
        }
    }

    // MARK: - Color for Values

    /// Returns a suggested color for displaying the value type
    public static func color(for value: ParquetValue) -> ValueColor {
        switch value {
        case .null:
            return .secondary
        case .bool(let b):
            return b ? .green : .red
        case .int, .float:
            return .blue
        case .string:
            return .primary
        case .binary:
            return .purple
        case .date, .timestamp:
            return .orange
        }
    }

    public enum ValueColor {
        case primary
        case secondary
        case blue
        case green
        case red
        case orange
        case purple
    }
}
