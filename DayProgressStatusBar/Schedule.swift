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
    
    var color: NSColor {
          NSColor(hex: colorHex) ?? .systemBlue
      }
}

extension NSColor {
    convenience init?(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        guard hexStr.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: hexStr).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
