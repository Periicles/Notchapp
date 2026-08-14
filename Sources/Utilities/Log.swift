import os

enum Log {
    private static let subsystem = "com.periicles.NotchBar"

    static let calendar = Logger(subsystem: subsystem, category: "calendar")
    static let panel = Logger(subsystem: subsystem, category: "panel")
    static let preferences = Logger(subsystem: subsystem, category: "preferences")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
}
