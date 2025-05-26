//
//  PopeverViewController.swift
//  DayProgressStatusBar
//
//  Created by john on 5/26/25.
//

import Cocoa

class PopoverViewController : NSViewController {
    // sample schedule list
    var schedules: [Schedule] = [
        Schedule(
            id: UUID(),
            title: "회사",
            start: DateComponents(hour: 9, minute: 0),
            end: DateComponents(hour: 18, minute: 0),
            colorHex: "#3182CE"
        ),
        Schedule(
            id: UUID(),
            title: "헬스장",
            start: DateComponents(hour: 19, minute: 10),
            end: DateComponents(hour: 20, minute: 15),
            colorHex: "#38A169"
        ),
        Schedule(
            id: UUID(),
            title: "공부",
            start: DateComponents(hour: 21, minute: 0),
            end: DateComponents(hour: 23, minute: 0),
            colorHex: "#DD6B20"
        ),
    ]
    
    
    override func loadView() {
        let scheduleCount = schedules.count
        let viewHeight = max(110, scheduleCount * 40 + 20)
        
        // 기본 뷰 생성: 크기와 색상만 우선 설정 (나중에 커스텀)
        let view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 270, height: viewHeight)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = view
        
        // 현재 시간 기준으로 포함되는 일정만 찾기
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        
        if schedules.isEmpty {
            let label = NSTextField(labelWithString: "등록된 일정이 없습니다.")
            label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
            label.textColor = NSColor.secondaryLabelColor
            label.alignment = .center
            label.frame = NSRect(x: 0, y: viewHeight / 2 - 12, width: 270, height: 24)
            view.addSubview(label)
            return
        }
        
        for (idx, schedule) in schedules.enumerated() {
            var startComp = schedule.start
            var endComp = schedule.end
            startComp.year = today.year
            startComp.month = today.month
            startComp.day = today.day
            endComp.year = today.year
            endComp.month = today.month
            endComp.day = today.day
            guard let start = calendar.date(from: startComp),
                  let end = calendar.date(from: endComp) else { continue }
            
            let progress: Double
            if now < start {
                progress = 0
            } else if now > end {
                progress = 1
            } else {
                progress = now.timeIntervalSince(start) / end.timeIntervalSince(start)
            }
            let percent = Int(progress * 100)
            
            let label = NSTextField(labelWithString: "\(formatTime(start)) ~ \(formatTime(end)) \(schedule.title) \(percent)%")
            label.frame = NSRect(x: 20, y: 110 - idx * 40, width: 230, height: 18) // Y값 충분히 벌려줌
            label.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
            label.textColor = NSColor.labelColor
            view.addSubview(label)
            
            // Optional: 각 일정의 bar도 넣고 싶으면 추가
            let progressBar = NSProgressIndicator()
            progressBar.frame = NSRect(x: 20, y: 92 - idx * 40, width: 180, height: 8)
            progressBar.minValue = 0
            progressBar.maxValue = 1
            progressBar.doubleValue = progress
            progressBar.isIndeterminate = false
            view.addSubview(progressBar)
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    func progress(for schedule : Schedule) -> Double {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let now  = Date()
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        
        // 오늘 날짜로 강제 세팅
        var startComp = schedule.start
        var endComp = schedule.end
        startComp.year = today.year
        startComp.month = today.month
        startComp.day = today.day
        endComp.year = today.year
        endComp.month = today.month
        endComp.day = today.day
        
        guard let start = calendar.date(from: startComp),
              let end = calendar.date(from: endComp) else { return 0 }
        
        if now <= start { return 0 }
        if now >= end { return 1 }
        let total = end.timeIntervalSince(start)
        let passed = now.timeIntervalSince(start)
        return passed / total
    }
}
