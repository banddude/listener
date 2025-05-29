import Foundation

struct DurationUtilities {
    // MARK: - Duration Formatting
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3_600
        let minutes = Int(seconds) % 3_600 / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    static func formatDurationCompact(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    static func formatMilliseconds(_ milliseconds: Double) -> String {
        let seconds = milliseconds / 1_000.0
        return formatDuration(seconds)
    }
    
    // MARK: - File Size Formatting
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Time Range Formatting
    static func formatTimeRange(start: Double, end: Double) -> String {
        let startTime = formatMilliseconds(start)
        let endTime = formatMilliseconds(end)
        return "\(startTime) - \(endTime)"
    }
}
