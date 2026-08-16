import Foundation

public enum LogLevel: Int, Sendable, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Minimal logging interface so call sites don't depend on a concrete
/// logger. Stage 1 only needs stdout output; a real structured/file
/// logger can replace `ConsoleLogger` later without touching call sites.
public protocol Logging: Sendable {
    func log(_ level: LogLevel, _ message: String, file: String, line: Int)
}

public extension Logging {
    func debug(_ message: String, file: String = #fileID, line: Int = #line) {
        log(.debug, message, file: file, line: line)
    }
    func info(_ message: String, file: String = #fileID, line: Int = #line) {
        log(.info, message, file: file, line: line)
    }
    func warning(_ message: String, file: String = #fileID, line: Int = #line) {
        log(.warning, message, file: file, line: line)
    }
    func error(_ message: String, file: String = #fileID, line: Int = #line) {
        log(.error, message, file: file, line: line)
    }
}

public struct ConsoleLogger: Logging {
    private let minimumLevel: LogLevel

    public init(minimumLevel: LogLevel = .info) {
        self.minimumLevel = minimumLevel
    }

    public func log(_ level: LogLevel, _ message: String, file: String, line: Int) {
        guard level >= minimumLevel else { return }
        let tag: String
        switch level {
        case .debug: tag = "DEBUG"
        case .info: tag = "INFO"
        case .warning: tag = "WARN"
        case .error: tag = "ERROR"
        }
        print("[\(tag)] \(file):\(line) — \(message)")
    }
}
