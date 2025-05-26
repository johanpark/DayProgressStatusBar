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
        let itemHeight = 40
        let maxVisible = 4
        let visibleCount = min(schedules.count, maxVisible)
        let contentHeight = max(110, visibleCount * itemHeight + 20)

        let baseView = NSView(frame: NSRect(x: 0, y: 0, width: 270, height: contentHeight))
        baseView.wantsLayer = true
        baseView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = baseView

        guard !schedules.isEmpty else {
            addNoScheduleLabel(to: baseView, contentHeight: contentHeight)
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)

        for (idx, schedule) in schedules.enumerated() {
            guard let (start, end) = resolvedDateRange(from: schedule, on: today, using: calendar) else { continue }
            let progress = clampedProgress(from: now, start: start, end: end)
            let percent = Int(progress * 100)
            let y = 110 - idx * itemHeight
            let views = makeScheduleView(for: idx, schedule: schedule, percent: percent, progress: progress, y: CGFloat(y), start: start, end: end)
            views.forEach { baseView.addSubview($0) }
        }
    }
    
    private func addNoScheduleLabel(to view: NSView, contentHeight: Int) {
        let label = NSTextField(labelWithString: "등록된 일정이 없습니다.")
        label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = NSColor.secondaryLabelColor
        label.alignment = .center
        label.frame = NSRect(x: 0, y: contentHeight / 2 - 12, width: 270, height: 24)
        view.addSubview(label)
    }

    private func resolvedDateRange(from schedule: Schedule, on day: DateComponents, using calendar: Calendar) -> (Date, Date)? {
        var startComp = schedule.start
        var endComp = schedule.end
        startComp.year = day.year
        startComp.month = day.month
        startComp.day = day.day
        endComp.year = day.year
        endComp.month = day.month
        endComp.day = day.day
        guard let start = calendar.date(from: startComp),
              let end = calendar.date(from: endComp) else { return nil }
        return (start, end)
    }

    private func clampedProgress(from now: Date, start: Date, end: Date) -> Double {
        if now <= start { return 0 }
        if now >= end { return 1 }
        return now.timeIntervalSince(start) / end.timeIntervalSince(start)
    }
    
    func makeScheduleView(for idx: Int, schedule: Schedule, percent: Int, progress:Double, y: CGFloat, start: Date, end: Date) -> [NSView] {
        // 1. 라벨
            let label = NSTextField(labelWithString: "\(formatTime(start)) ~ \(formatTime(end)) \(schedule.title) \(percent)%")
            label.frame = NSRect(x: 20, y: y, width: 230, height: 18)
            label.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
            label.textColor = NSColor.labelColor
            
            // 2. ProgressBar
            let progressBar = NSProgressIndicator()
            progressBar.frame = NSRect(x: 20, y: y - 18, width: 180, height: 8)
            progressBar.minValue = 0
            progressBar.maxValue = 1
            progressBar.doubleValue = progress
            progressBar.isIndeterminate = false
            
            return [label, progressBar]
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
