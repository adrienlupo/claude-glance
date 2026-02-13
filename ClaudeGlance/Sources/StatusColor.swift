import SwiftUI

enum SessionStatus: String, Codable, Hashable {
    case idle
    case busy
    case waiting

    var color: Color {
        switch self {
        case .idle: Color(red: 0.204, green: 0.780, blue: 0.349)
        case .busy: Color(red: 1.0, green: 0.624, blue: 0.039)
        case .waiting: Color(red: 1.0, green: 0.271, blue: 0.227)
        }
    }
}
