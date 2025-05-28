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
        var calendar = Calendar.current
            calendar.timeZone = TimeZone.current
        let today = calendar.dateComponents([.year, .month, .day], from:now)
        if let s = schedules.first(where: { schedule in
            var startComp = schedule.start
            var endComp = schedule.end
            startComp.year = today.year
            startComp.month = today.month
            startComp.day = today.day
            endComp.year = today.year
            endComp.month = today.month
            endComp.day = today.day
            guard let start = calendar.date(from: startComp),
                  let end = calendar.date(from: endComp) else {return false}
            return (now >= start) && (now <= end)
        }) {
            let start = calendar.date(from: {
                var comp = s.start
                comp.year = today.year; comp.month = today.month; comp.day = today.day
                return comp
            }())!
            let end = calendar.date(from: {
                var comp = s.end
                comp.year = today.year; comp.month = today.month; comp.day = today.day
                return comp
            }())!
            let progress = (now.timeIntervalSince(start) / end.timeIntervalSince(start))
            return max(0, min(100, Int(progress * 100)))
        }
        return nil
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
