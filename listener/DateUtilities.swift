import Foundation

struct DateUtilities {
    // MARK: - Shared Formatters
    static let conversationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()
    
    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
    
    // MARK: - Convenience Methods
    static func formatConversationDate(_ date: Date) -> String {
        conversationDateFormatter.string(from: date)
    }
    
    static func formatDetailDate(_ date: Date) -> String {
        detailDateFormatter.string(from: date)
    }
    
    static func formatTimestamp(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }
    
    static func parseISODate(_ dateString: String) -> Date? {
        isoDateFormatter.date(from: dateString)
    }
}
