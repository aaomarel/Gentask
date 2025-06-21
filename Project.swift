import Foundation

struct Project: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
}
