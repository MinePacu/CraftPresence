import Foundation

struct Item: Identifiable, Equatable, Hashable {
    let id = UUID()
    var timestamp: Date
}
