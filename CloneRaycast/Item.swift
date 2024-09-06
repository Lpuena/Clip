//
//  Item.swift
//  CloneRaycast
//
//  Created by GGG on 2024/9/6.
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
