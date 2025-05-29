//
//  PopeverViewController.swift
//  DayProgressStatusBar
//
//  Created by john on 5/26/25.
//

import Cocoa

class PopoverViewController : NSViewController {
    var schedules: [Schedule] = ScheduleStorage.shared.load()
    
    var isEditing: Bool = false
    var editingIndex: Int?
    
    var activeWindowController: ScheduleEditWindowController?
    
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
        let editor = ScheduleEditWindowController(schedule: nil)
        self.activeWindowController = editor
        editor.showWindow(nil)
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
        
        let repButton = NSButton(title: schedule.isRepresentative ? "●" : "○", target: self, action: #selector(toggleRepresentative(_:)))
        repButton.tag = idx
        repButton.bezelStyle = .inline
        repButton.setButtonType(.momentaryPushIn)
        repButton.setContentHuggingPriority(.required, for: .horizontal)

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

        hStack.addArrangedSubview(repButton)
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
        let idx = sender.tag
        let schedule = schedules[idx]
        let editor = ScheduleEditWindowController(schedule: schedule, index: idx)
        self.activeWindowController = editor
        editor.showWindow(nil)
    }
    
    @objc func deleteScheduleTapped(_ sender: NSButton) {
        deleteSchedule(at: sender.tag)
        NotificationCenter.default.post(name: .scheduleListUpdated, object: nil)
        reloadSchedules()
    }
    
    @objc func toggleRepresentative(_ sender: NSButton) {
        let idx = sender.tag
        let isCurrentlyRepresentative = schedules[idx].isRepresentative

        for i in 0..<schedules.count {
            schedules[i].isRepresentative = false
        }
        
        schedules[idx].isRepresentative = !isCurrentlyRepresentative
        
        ScheduleStorage.shared.save(schedules)
        NotificationCenter.default.post(name: .scheduleListUpdated, object: nil)
        reloadSchedules()
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScheduleSaved(_:)),
            name: .scheduleSaved,
            object: nil
        )
    }
    
    @objc func handleScheduleSaved(_ notification: Notification) {
        guard let (schedule, index) = notification.object as? (Schedule, Int?) else { return }

        if let i = index {
            // 수정된 일정 반영
            schedules[i] = schedule
        } else {
            // 신규 일정 추가
            schedules.append(schedule)
        }

        // 저장
        ScheduleStorage.shared.save(schedules)

        // UI 리로드
        reloadSchedules()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
