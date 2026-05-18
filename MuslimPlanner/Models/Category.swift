import Foundation
import SwiftData

@Model
final class Category {
    var name: String
    var colorHex: String
    var symbolName: String

    init(name: String, colorHex: String = "007AFF", symbolName: String = "tag.fill") {
        self.name = name
        self.colorHex = colorHex
        self.symbolName = symbolName
    }
}
