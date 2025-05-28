//
//  PopeverViewController.swift
//  DayProgressStatusBar
//
//  Created by john on 5/26/25.
//

import Cocoa

class PopoverViewController : NSViewController {
    var schedules: [Schedule] = ScheduleStorage.shared.load()
    
    var formView: ScheduleFormView?
    var isEditing: Bool = false
    var editingIndex: Int?
    
    override func loadView() {
        let itemHeight = 40
        let maxVisible = 4
        let width: CGFloat = 270
        let baseView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 200))
        baseView.wantsLayer = true
        baseView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = baseView

        // Create vertical stack view
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 10
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        baseView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor, constant: -10),
            stackView.topAnchor.constraint(equalTo: baseView.topAnchor, constant: 10)
        ])

        // Add ScheduleFormView into stack (initially hidden)
        let form = ScheduleFormView(frame: NSRect(x: 0, y: 0, width: width - 20, height: 140))
        form.isHidden = true
        self.formView = form
        stackView.addArrangedSubview(form)

        // + button at the bottom
        let addButton = NSButton(title: "+", target: self, action: #selector(addScheduleTapped))
        addButton.setContentHuggingPriority(.required, for: .horizontal)
        addButton.setContentHuggingPriority(.required, for: .vertical)

        // If no schedules, show label
        if schedules.isEmpty {
            let label = NSTextField(labelWithString: "등록된 일정이 없습니다.")
            label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
            label.textColor = NSColor.secondaryLabelColor
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(label)
            // Add stretchable space before addButton
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
            stackView.addArrangedSubview(spacer)
            stackView.addArrangedSubview(addButton)
            // Set content height
            let contentHeight: CGFloat = 160
            baseView.setFrameSize(NSSize(width: width, height: contentHeight))
            return
        }

        // Schedule views
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        var scheduleViews: [NSView] = []
        for (idx, schedule) in schedules.enumerated() {
            guard let (start, end) = resolvedDateRange(from: schedule, on: today, using: calendar) else { continue }
            let progress = clampedProgress(from: now, start: start, end: end)
            let percent = Int(progress * 100)
            let views = makeScheduleStackItem(for: idx, schedule: schedule, percent: percent, progress: progress, start: start, end: end)
            scheduleViews.append(views)
        }
        // If too many, wrap in scrollview
        if scheduleViews.count > maxVisible {
            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.borderType = .noBorder
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            let innerStack = NSStackView(views: scheduleViews)
            innerStack.orientation = .vertical
            innerStack.spacing = 10
            innerStack.alignment = .leading
            innerStack.translatesAutoresizingMaskIntoConstraints = false
            scrollView.documentView = innerStack
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollView.drawsBackground = false
            scrollView.autohidesScrollers = true
            scrollView.hasVerticalScroller = true
            // Set scrollView height to show maxVisible items
            let scrollHeight: CGFloat = CGFloat(maxVisible) * CGFloat(itemHeight) + CGFloat((maxVisible-1)*10)
            scrollView.heightAnchor.constraint(equalToConstant: scrollHeight).isActive = true
            stackView.addArrangedSubview(scrollView)
        } else {
            scheduleViews.forEach { stackView.addArrangedSubview($0) }
        }
        // Add stretchable space before addButton
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacer)
        stackView.addArrangedSubview(addButton)
        // Calculate content height
        let visibleCount = min(schedules.count, maxVisible)
        let contentHeight = CGFloat(visibleCount * itemHeight + 20 + 40 + 10 * (visibleCount-1))
        let minHeight: CGFloat = 160
        let totalHeight = max(minHeight, contentHeight)
        baseView.setFrameSize(NSSize(width: width, height: totalHeight))
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
    
    // NSStackView-based schedule item
    func makeScheduleStackItem(for idx: Int, schedule: Schedule, percent: Int, progress: Double, start: Date, end: Date) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 2
        container.alignment = .leading
        container.translatesAutoresizingMaskIntoConstraints = false

        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.spacing = 8
        hStack.alignment = .centerY
        hStack.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "\(formatTime(start)) ~ \(formatTime(end)) \(schedule.title) \(percent)%")
        label.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = NSColor.labelColor
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        let editButton = NSButton(title: "✎", target: self, action: #selector(editScheduleTapped(_:)))
        editButton.tag = idx
        editButton.setButtonType(.momentaryPushIn)
        editButton.bezelStyle = .inline
        editButton.setContentHuggingPriority(.required, for: .horizontal)
        let deleteButton = NSButton(title: "🗑", target: self, action: #selector(deleteScheduleTapped(_:)))
        deleteButton.tag = idx
        deleteButton.setButtonType(.momentaryPushIn)
        deleteButton.bezelStyle = .inline
        deleteButton.setContentHuggingPriority(.required, for: .horizontal)

        hStack.addArrangedSubview(label)
        hStack.addArrangedSubview(editButton)
        hStack.addArrangedSubview(deleteButton)
        // ProgressBar
        let progressBar = NSProgressIndicator()
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = progress
        progressBar.isIndeterminate = false
        progressBar.controlSize = .small
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.widthAnchor.constraint(equalToConstant: 180).isActive = true
        progressBar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        container.addArrangedSubview(hStack)
        container.addArrangedSubview(progressBar)
        return container
    }
    
    @objc func editScheduleTapped(_ sender: NSButton) {
        showScheduleForm(editing: sender.tag)
    }
    
    @objc func deleteScheduleTapped(_ sender: NSButton) {
        deleteSchedule(at: sender.tag)
        NotificationCenter.default.post(name: .scheduleListUpdated, object: nil)
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
        
        
        override init(frame frameRect: NSRect) {
            titleField = NSTextField(frame: NSRect(x: 10, y: 100, width: 230, height: 24))
            startPicker = NSDatePicker(frame: NSRect(x: 10, y: 70, width: 230, height: 24))
            endPicker = NSDatePicker(frame: NSRect(x: 10, y: 40, width: 230, height: 24))
            colorWell = NSColorWell(frame: NSRect(x: 10, y: 10, width: 50, height: 24))
            saveButton = NSButton(frame: NSRect(x: 70, y: 10, width: 50, height: 24))
            cancelButton = NSButton(frame: NSRect(x: 130, y: 10, width: 50, height: 24))
            super.init(frame: frameRect)
            saveButton.title = "Save"
            cancelButton.title = "Cancel"
            addSubview(titleField)
            addSubview(startPicker)
            addSubview(endPicker)
            addSubview(colorWell)
            addSubview(saveButton)
            addSubview(cancelButton)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    func showScheduleForm(editing index: Int?) {

        
        formView?.removeFromSuperview()  // 기존 폼 제거
        
        let form = ScheduleFormView(frame: NSRect(x: 10, y: view.frame.height - 160, width: 250, height: 140))
        self.formView = form
        self.view.addSubview(form)
        
        if let i = index {
            //수정 : 값 세팅
            let schedule = schedules[i]
            form.titleField.stringValue = schedule.title
            form.startPicker.dateValue = Calendar.current.date(from: schedule.start) ?? Date()
            form.endPicker.dateValue = Calendar.current.date(from: schedule.end) ?? Date()
            form.colorWell.color = NSColor(hex: schedule.colorHex) ?? .systemBlue
        } else {
            // 등록 : 초기화
            form.titleField.stringValue = ""
            form.startPicker.dateValue = Date()
            form.endPicker.dateValue = Date()
            form.colorWell.color = NSColor.systemBlue
            editingIndex = nil
        }
        
        form.saveButton.target = self
        form.saveButton.action = #selector(saveScheduleTapped)
        
        form.cancelButton.target = self
        form.cancelButton.action = #selector(cancelScheduleTapped)
    }
    
    @objc func saveScheduleTapped() {
        guard let form = formView else { return }

        let title = form.titleField.stringValue
        let now = Date()
        let today = Calendar.current.dateComponents([.year, .month, .day], from: now)

        var start = Calendar.current.dateComponents([.hour, .minute], from: form.startPicker.dateValue)
        var end = Calendar.current.dateComponents([.hour, .minute], from: form.endPicker.dateValue)

        start.year = today.year
        start.month = today.month
        start.day = today.day

        end.year = today.year
        end.month = today.month
        end.day = today.day

        let colorHex = form.colorWell.color.hexString

        let newSchedule = Schedule(id: UUID(), title: title, start: start, end: end, colorHex: colorHex)

        if hasConflictSchedule(start: start, end: end, ignoreIndex: editingIndex) {
            let alert = NSAlert()
            alert.messageText = "중복된 일정이 있습니다."
            alert.informativeText = "겹치지 않도록 시간을 조정해주세요."
            alert.runModal()
            return
        }

        if let i = editingIndex {
            schedules[i] = newSchedule
            ScheduleStorage.shared.save(schedules)
        } else {
            schedules.append(newSchedule)
            ScheduleStorage.shared.save(schedules)
        }

        form.removeFromSuperview()
        formView = nil
        editingIndex = nil
        NotificationCenter.default.post(name: .scheduleListUpdated, object: nil)
        reloadSchedules()
    }
    
    func hasConflictSchedule(start: DateComponents, end: DateComponents, ignoreIndex: Int? = nil) -> Bool {
        let calendar = Calendar.current

        for (index, schedule) in schedules.enumerated() {
            if let ignore = ignoreIndex, index == ignore { continue }

            guard let s1 = calendar.date(from: schedule.start),
                  let e1 = calendar.date(from: schedule.end),
                  let s2 = calendar.date(from: start),
                  let e2 = calendar.date(from: end) else { continue }

            // 겹치는 시간 여부
            if s1 < e2 && s2 < e1 {
                return true
            }
        }
        return false
    }
    
    @objc func cancelScheduleTapped() {
        formView?.removeFromSuperview()
        formView = nil
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
        ScheduleStorage.shared.save(schedules)
    }
    
    func reloadSchedules() {
        // Remove all subviews from the view
        view.subviews.forEach { $0.removeFromSuperview() }

        let itemHeight = 40
        let maxVisible = 4
        let width: CGFloat = 270
        let baseView = view

        // Create vertical stack view
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 10
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        baseView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor, constant: -10),
            stackView.topAnchor.constraint(equalTo: baseView.topAnchor, constant: 10)
        ])

        // Add ScheduleFormView into stack (initially hidden)
        if formView == nil {
            let form = ScheduleFormView(frame: NSRect(x: 0, y: 0, width: width - 20, height: 140))
            form.isHidden = true
            self.formView = form
        }
        if let form = formView {
            stackView.addArrangedSubview(form)
        }

        // + button at the bottom
        let addButton = NSButton(title: "+", target: self, action: #selector(addScheduleTapped))
        addButton.setContentHuggingPriority(.required, for: .horizontal)
        addButton.setContentHuggingPriority(.required, for: .vertical)

        // If no schedules, show label
        if schedules.isEmpty {
            let label = NSTextField(labelWithString: "등록된 일정이 없습니다.")
            label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
            label.textColor = NSColor.secondaryLabelColor
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(label)
            // Add stretchable space before addButton
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
            stackView.addArrangedSubview(spacer)
            stackView.addArrangedSubview(addButton)
            // Set content height
            let contentHeight: CGFloat = 160
            baseView.setFrameSize(NSSize(width: width, height: contentHeight))
            return
        }

        // Schedule views
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        var scheduleViews: [NSView] = []
        for (idx, schedule) in schedules.enumerated() {
            guard let (start, end) = resolvedDateRange(from: schedule, on: today, using: calendar) else { continue }
            let progress = clampedProgress(from: now, start: start, end: end)
            let percent = Int(progress * 100)
            let view = makeScheduleStackItem(for: idx, schedule: schedule, percent: percent, progress: progress, start: start, end: end)
            scheduleViews.append(view)
        }
        // If too many, wrap in scrollview
        if scheduleViews.count > maxVisible {
            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.borderType = .noBorder
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            let innerStack = NSStackView(views: scheduleViews)
            innerStack.orientation = .vertical
            innerStack.spacing = 10
            innerStack.alignment = .leading
            innerStack.translatesAutoresizingMaskIntoConstraints = false
            scrollView.documentView = innerStack
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollView.drawsBackground = false
            scrollView.autohidesScrollers = true
            scrollView.hasVerticalScroller = true
            // Set scrollView height to show maxVisible items
            let scrollHeight: CGFloat = CGFloat(maxVisible) * CGFloat(itemHeight) + CGFloat((maxVisible-1)*10)
            scrollView.heightAnchor.constraint(equalToConstant: scrollHeight).isActive = true
            stackView.addArrangedSubview(scrollView)
        } else {
            scheduleViews.forEach { stackView.addArrangedSubview($0) }
        }
        // Add stretchable space before addButton
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacer)
        stackView.addArrangedSubview(addButton)
        // Calculate content height
        let visibleCount = min(schedules.count, maxVisible)
        let contentHeight = CGFloat(visibleCount * itemHeight + 20 + 40 + 10 * (visibleCount-1))
        let minHeight: CGFloat = 160
        let totalHeight = max(minHeight, contentHeight)
        baseView.setFrameSize(NSSize(width: width, height: totalHeight))
    }
}
