public import os

/// Native Logger interpolation preserves privacy at each call site.
public enum Log {
    public static let data = Logger(subsystem: "com.example.MyApp", category: "data")
}
