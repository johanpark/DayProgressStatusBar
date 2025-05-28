//
//  ScheduleStorage.swift
//  DayProgressStatusBar
//
//  Created by 박요한 on 5/28/25.
//

import Foundation

class ScheduleStorage {
    static let shared = ScheduleStorage()
    private let key = "saveSchedules"
    
    func save(_ schedules: [Schedule]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(schedules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func load() -> [Schedule] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        if let schedules = try? decoder.decode([Schedule].self, from: data) {
            return schedules.sorted { s1, s2 in
                let cal = Calendar.current
                let d1 = cal.date(from: s1.start) ?? Date.distantPast
                let d2 = cal.date(from: s2.start) ?? Date.distantPast
                return d1 < d2
            }
        }
        return []
    }
}
