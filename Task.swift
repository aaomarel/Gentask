import Foundation
import SwiftUI

enum TaskPriority: String, CaseIterable, Codable, Identifiable {
    case low, medium, high
    
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var color: Color {
        switch self {
        case .low: .green
        case .medium: .yellow
        case .high: .red
        }
    }
}

struct Task: Identifiable, Codable, Hashable {
    var id = UUID() // Use let for a truly constant ID
    var title: String
    var isCompleted: Bool
    var deadline: Date? = nil
    var priority: TaskPriority = .medium
    var notes: String? = nil
    var subtasks: [Task] = []
    
    // CORRECTED: Make creationDate optional to handle loading old data gracefully.
    var creationDate: Date?
}
