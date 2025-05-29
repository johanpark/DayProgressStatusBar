//
//  AppDelegate.swift
//  DayProgressStatusBar
//
//  Created by john on 5/26/25.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var timer: Timer?
    
    var schedules: [Schedule] {
        ScheduleStorage.shared.load()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "0%"
        
        // 1. 팝오버 생성
        popover = NSPopover()
        popover.contentViewController = PopoverViewController()
        popover.behavior = .transient // 포커스 잃으면 자동 닫힘
        
        // 2. 상단바 클릭 이벤트 연결
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            _ in self.updateStatusBarPercent()
        }
        updateStatusBarPercent()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scheduleListDidUpdate),
            name: .scheduleListUpdated,
            object: nil
        )
    }
    
    @objc func scheduleListDidUpdate() {
        updateStatusBarPercent()
    }
    
    func updateStatusBarPercent() {
        let percent = currentSchedulePercent()
        DispatchQueue.main.async {
            self.statusItem.button?.title = percent != nil ? "\(percent!)%" : "0%"
        }
    }
    
    func currentSchedulePercent() -> Int? {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)

        let allSchedules = schedules

        // ✅ 1. 대표 일정 우선 처리
        if let rep = allSchedules.first(where: { $0.isRepresentative }) {
            return calculatePercent(for: rep, on: today, now: now)
        }

        // ✅ 2. 현재 시간 겹치는 일정 중 가장 빠른 것
        let candidates = allSchedules.compactMap { schedule -> (Schedule, Date)? in
            var startComp = schedule.start
            startComp.year = today.year; startComp.month = today.month; startComp.day = today.day
            guard let startDate = calendar.date(from: startComp) else { return nil }

            var endComp = schedule.end
            endComp.year = today.year; endComp.month = today.month; endComp.day = today.day
            guard let endDate = calendar.date(from: endComp) else { return nil }

            return (now >= startDate && now <= endDate) ? (schedule, startDate) : nil
        }

        if let selected = candidates.sorted(by: { $0.1 < $1.1 }).first {
            return calculatePercent(for: selected.0, on: today, now: now)
        }

        return nil
    }

    func calculatePercent(for schedule: Schedule, on today: DateComponents, now: Date) -> Int {
        var calendar = Calendar.current
        var startComp = schedule.start
        var endComp = schedule.end
        startComp.year = today.year; startComp.month = today.month; startComp.day = today.day
        endComp.year = today.year; endComp.month = today.month; endComp.day = today.day
        guard let start = calendar.date(from: startComp),
              let end = calendar.date(from: endComp) else { return 0 }
        let progress = now.timeIntervalSince(start) / end.timeIntervalSince(start)
        return max(0, min(100, Int(progress * 100)))
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                let popVC = PopoverViewController()
                            popover.contentViewController = popVC
                            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
