import SwiftUI

enum SessionStatus: String, Codable, Hashable {
    case idle
    case busy
    case waiting
    case disconnected

    var label: String {
        switch self {
        case .idle: "idle"
        case .busy: "working"
        case .waiting: "input needed"
        case .disconnected: "disconnected"
        }
    }

    var color: Color {
        switch self {
        case .idle: Color(red: 0.204, green: 0.780, blue: 0.349)
        case .busy: Color(red: 1.0, green: 0.624, blue: 0.039)
        case .waiting: Color(red: 1.0, green: 0.271, blue: 0.227)
        case .disconnected: Color(red: 0.557, green: 0.557, blue: 0.576)
        }
    }

    var nsColor: NSColor {
        NSColor(color)
    }

    var priority: Int {
        switch self {
        case .waiting: 3
        case .busy: 2
        case .idle: 1
        case .disconnected: 0
        }
    }
}
