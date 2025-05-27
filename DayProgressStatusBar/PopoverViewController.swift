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
    
    var formView: ScheduleFormView?
    var isEditing: Bool = false
    var editingIndex: Int?
    
    override func loadView() {
        let itemHeight = 40
        let maxVisible = 4
        let visibleCount = min(schedules.count, maxVisible)
        let contentHeight = max(110, visibleCount * itemHeight + 20)
        
        let baseView = NSView(frame: NSRect(x: 0, y: 0, width: 270, height: contentHeight))
        baseView.wantsLayer = true
        baseView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = baseView
        
        // +추가 버튼
        let addButton = NSButton(title: "+", target: self, action: #selector(addScheduleTapped))
        addButton.frame = NSRect(x: 230, y: contentHeight - 36, width: 30, height: 30)
        baseView.addSubview(addButton)
        
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
    
    @objc func addScheduleTapped() {
         showScheduleForm(editing: nil)
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
        
        // 수정 버튼
        let editButton = NSButton(title: "✎", target: self, action: #selector(editScheduleTapped(_:)))
        editButton.tag = idx
        // 삭제 버튼
        let deleteButton = NSButton(title: "🗑", target: self, action: #selector(deleteScheduleTapped(_:)))
        deleteButton.tag = idx
        
        return [label, progressBar, editButton, deleteButton]
    }
    
    @objc func editScheduleTapped(_ sender: NSButton) {
        showScheduleForm(editing: sender.tag)
    }

    @objc func deleteScheduleTapped(_ sender: NSButton) {
        deleteSchedule(at: sender.tag)
        reloadSchedules()
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
    
    
    // ScheduleFormView: 등록/수정 폼 (팝오버 내에 뷰로 삽입)
    class ScheduleFormView : NSView {
        var titleField: NSTextField
        var startPicker : NSDatePicker
        var endPicker:NSDatePicker
        var colorWell : NSColorWell
        var saveButton: NSButton
        var cancelButton: NSButton
    }
    
    func showScheduleForm(editing index: Int?) {
      // ScheduleFormView 인스턴스 생성
      // index 있으면 기존 값 세팅, 없으면 빈 폼
      // 저장/취소 버튼에 액션 연결
      // 이미 폼이 있으면 덮어쓰기/교체
      // self.formView = form
      // self.view.addSubview(form)
    }
    
    func saveSchedule() {
        // formView에서 값 읽기
          // 신규/수정 분기
          // 1) 겹치는 시간 체크
          // 2) 문제없으면 schedules에 반영
          // 폼 뷰 remove, 리스트 리로드
    }

    func deleteSchedule(at index: Int) {
        schedules.remove(at: index)
    }
    
    func reloadSchedules() {
         // self.view.subviews.removeAll()
         // self.loadView()
         // or 좀 더 세련되게 diff/애니메이션 처리
     }
}
