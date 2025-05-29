//
//  Schedule.swift
//  DayProgressStatusBar
//
//  Created by john on 5/26/25.
//

import Foundation
import Cocoa

struct Schedule : Codable, Identifiable{
    let id: UUID
    let title: String
    let start : DateComponents
    let end : DateComponents
    let colorHex : String
    var isRepresentative: Bool
    
    var color: NSColor {
          NSColor(hex: colorHex) ?? .systemBlue
      }
}
