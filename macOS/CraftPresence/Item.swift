//
//  Item.swift
//  CraftPresence
//
//  Created by 노현수 on 10/31/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
