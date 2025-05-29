import Foundation

struct AppConstants {
    // MARK: - API Configuration
    static let baseURL = "https://speaker-id-server-production.up.railway.app"
    
    // MARK: - Audio Configuration
    static let defaultSilenceThreshold: TimeInterval = 2.0
    static let maxSilenceThreshold: TimeInterval = 60.0
    static let minSilenceThreshold: TimeInterval = 1.0
    
    // MARK: - UI Configuration
    static let defaultAnimationDuration: Double = 0.3
    static let maxFileDisplayCount = 100
    
    // MARK: - File Configuration
    static let audioFileExtension = "m4a"
    static let maxFileSizeBytes: Int64 = 100 * 1_024 * 1_024 // 100MB
    
    // MARK: - Buffer Configuration
    static let circularBufferSize = 1_024 * 1_024 // 1MB
}
