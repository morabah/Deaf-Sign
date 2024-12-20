import Foundation
import os

/// Comprehensive logging and error handling utility for the Nuby application
/// Provides centralized logging, error tracking, and diagnostic capabilities
enum Logger {
    /// Logging levels with increasing severity
    enum Level {
        case trace      // Very detailed tracing information
        case debug      // Debugging information
        case info       // General information about app state
        case warning    // Potential issues that don't prevent functionality
        case error      // Serious errors that may impact app performance
        case critical   // Catastrophic errors that prevent core functionality
    }
    
    /// Internal logger using Apple's Unified Logging system
    private static let logger = os.Logger(subsystem: "com.nuby.app", category: "main")
    
    /// Logs a message with comprehensive details
    /// - Parameters:
    ///   - message: The primary message to log
    ///   - level: The severity level of the log
    ///   - file: Source file of the log (auto-populated)
    ///   - function: Function where the log originated (auto-populated)
    ///   - line: Line number of the log (auto-populated)
    static func log(
        _ message: String,
        level: Level = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [\(fileName):\(line)] \(function) | \(message)"
        
        // Log to both console and Apple's unified logging system
        switch level {
        case .trace:
            print("🔍 TRACE: \(logMessage)")
            if #available(iOS 14.0, *) {
                logger.trace("\(logMessage)")
            } else {
                logger.debug("\(logMessage)")
            }
        case .debug:
            print("🐞 DEBUG: \(logMessage)")
            logger.debug("\(logMessage)")
        case .info:
            print("ℹ️ INFO: \(logMessage)")
            logger.info("\(logMessage)")
        case .warning:
            print("⚠️ WARNING: \(logMessage)")
            logger.warning("\(logMessage)")
        case .error:
            print("❌ ERROR: \(logMessage)")
            logger.error("\(logMessage)")
        case .critical:
            print("🚨 CRITICAL: \(logMessage)")
            logger.fault("\(logMessage)")
            
            // For critical errors, we might want to take additional actions
            handleCriticalError(message: logMessage)
        }
    }
    
    /// Handle critical errors that require immediate attention
    private static func handleCriticalError(message: String) {
        // Save critical error to persistent storage
        saveCriticalError(message)
        
        // Could integrate with crash reporting service
        // reportCriticalError(message)
    }
    
    /// Save critical error to persistent storage for later analysis
    private static func saveCriticalError(_ message: String) {
        let userDefaults = UserDefaults.standard
        var criticalErrors = userDefaults.array(forKey: "CriticalErrors") as? [String] ?? []
        criticalErrors.append(message)
        
        // Keep only the last 100 critical errors
        if criticalErrors.count > 100 {
            criticalErrors.removeFirst(criticalErrors.count - 100)
        }
        
        userDefaults.set(criticalErrors, forKey: "CriticalErrors")
    }
    
    /// Comprehensive error handling and logging
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: Additional context about the error
    ///   - level: Severity level of the error
    ///   - file: Source file of the error
    ///   - function: Function where the error occurred
    ///   - line: Line number of the error
    static func handle(
        _ error: Error,
        context: String? = nil,
        level: Level = .error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let errorDescription = context ?? "Unhandled error"
        
        // Log the error with detailed information
        let fullErrorMessage = """
        Error in [\(fileName):\(line)] \(function)
        Context: \(errorDescription)
        Error: \(error.localizedDescription)
        """
        
        // Log based on severity
        switch level {
        case .warning:
            print("⚠️ WARNING: \(fullErrorMessage)")
            logger.warning("\(fullErrorMessage)")
        case .error:
            print("❌ ERROR: \(fullErrorMessage)")
            logger.error("\(fullErrorMessage)")
        case .critical:
            print("🚨 CRITICAL: \(fullErrorMessage)")
            logger.fault("\(fullErrorMessage)")
        default:
            log(fullErrorMessage, level: .error)
        }
        
        // Optional: Additional error tracking or reporting
        // Could integrate with crash reporting services like Firebase Crashlytics
        // trackError(error)
    }
    
    /// Tracks and reports non-fatal errors
    /// - Parameter error: The error to track
    private static func trackError(_ error: Error) {
        // Placeholder for error tracking service integration
        // Example: FirebaseCrashlytics.shared().record(error: error)
    }
}

/// Custom error types for more specific error handling
enum NubyError: Error {
    case databaseConnectionFailed
    case dataParsingFailed
    case networkRequestFailed
    case insufficientPermissions
    case unknownError
    
    /// Provides a human-readable description for each error type
    var localizedDescription: String {
        switch self {
        case .databaseConnectionFailed:
            return "Unable to connect to the movie database"
        case .dataParsingFailed:
            return "Failed to parse movie data"
        case .networkRequestFailed:
            return "Network request could not be completed"
        case .insufficientPermissions:
            return "You do not have sufficient permissions"
        case .unknownError:
            return "An unexpected error occurred"
        }
    }
}
