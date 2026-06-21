import os

/// Lightweight logging facade so layers don't depend on a concrete logging backend.
/// Swap the implementation here without touching call sites.
public enum Log {
    private static let logger = Logger(subsystem: "com.example.MyApp", category: "app")

    public static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    public static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    public static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
