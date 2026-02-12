import SwiftUI

enum SessionStatus: String, Codable, Hashable {
    case idle
    case busy
    case waiting
    case interrupted
    case disconnected

    var label: String {
        switch self {
        case .idle: "done"
        case .busy: "working"
        case .waiting: "input needed"
        case .interrupted: "interrupted"
        case .disconnected: "disconnected"
        }
    }

    var color: Color {
        switch self {
        case .idle: Color(red: 0.204, green: 0.780, blue: 0.349)
        case .busy: Color(red: 1.0, green: 0.624, blue: 0.039)
        case .waiting: Color(red: 1.0, green: 0.271, blue: 0.227)
        case .interrupted: Color(red: 0.557, green: 0.557, blue: 0.576)
        case .disconnected: Color(red: 0.557, green: 0.557, blue: 0.576)
        }
    }

    var nsColor: NSColor {
        switch self {
        case .idle: NSColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1)
        case .busy: NSColor(red: 1.0, green: 0.624, blue: 0.039, alpha: 1)
        case .waiting: NSColor(red: 1.0, green: 0.271, blue: 0.227, alpha: 1)
        case .interrupted: NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1)
        case .disconnected: NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1)
        }
    }

    var priority: Int {
        switch self {
        case .waiting: 3
        case .busy: 2
        case .idle: 1
        case .interrupted: 1
        case .disconnected: 0
        }
    }
}
