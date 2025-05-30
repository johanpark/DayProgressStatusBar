//
//  PopeverViewController.swift
//  DayProgressStatusBar
//
//  Created by john on 5/26/25.
//

import Cocoa

class PopoverViewController : NSViewController, NSPopoverDelegate {
    var schedules: [Schedule] = ScheduleStorage.shared.load()
    
    var isEditing: Bool = false
    var editingIndex: Int?
    
    var activeWindowController: ScheduleEditWindowController?
    
    // baseView, stackView, scrollView, innerStack, addButton, spacer를 인스턴스 변수로 선언
    let baseView = NSView()
    let stackView = NSStackView()
    let scrollView = NSScrollView()
    let innerStack = NSStackView()
    let addButton = NSButton(title: "+", target: nil, action: nil)
    let spacer = NSView()
    var scrollHeightConstraint: NSLayoutConstraint?
    
    // --- 추가: 대표 일정 카드, 더보기, 인라인 추가, 설정 버튼 관련 변수 ---
    let cardContainer = NSView()
    let cardTitleLabel = NSTextField(labelWithString: "")
    let cardTimeLabel = NSTextField(labelWithString: "")
    let cardProgressBar = NSProgressIndicator()
    let moreButton = NSButton(title: "더보기", target: nil, action: nil)
    let settingsButton = NSButton(title: "설정", target: nil, action: nil)
    var isExpanded = false
    var isAdding = false
    
    override func loadView() {
        let width: CGFloat = 270
        baseView.frame = NSRect(x: 0, y: 0, width: width, height: 320)
        baseView.wantsLayer = true
        baseView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = baseView

        // StackView 설정
        stackView.orientation = .vertical
        stackView.spacing = 10
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        baseView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor, constant: -10),
            stackView.topAnchor.constraint(equalTo: baseView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor, constant: -10)
        ])

        // --- 대표 일정 카드 UI ---
        cardContainer.wantsLayer = true
        cardContainer.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.12).cgColor
        cardContainer.layer?.cornerRadius = 8
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        cardTitleLabel.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        cardTitleLabel.textColor = NSColor.labelColor
        cardTimeLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        cardTimeLabel.textColor = NSColor.secondaryLabelColor
        cardTimeLabel.isHidden = false
        cardTimeLabel.maximumNumberOfLines = 1
        cardTimeLabel.lineBreakMode = .byTruncatingTail
        cardProgressBar.minValue = 0
        cardProgressBar.maxValue = 1
        cardProgressBar.isIndeterminate = false
        cardProgressBar.controlSize = .regular
        cardProgressBar.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(cardTitleLabel)
        cardContainer.addSubview(cardTimeLabel)
        cardContainer.addSubview(cardProgressBar)
        cardTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cardTitleLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 12),
            cardTitleLabel.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 10),
            cardTitleLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -12),
            cardTimeLabel.leadingAnchor.constraint(equalTo: cardTitleLabel.leadingAnchor),
            cardTimeLabel.topAnchor.constraint(equalTo: cardTitleLabel.bottomAnchor, constant: 2),
            cardTimeLabel.trailingAnchor.constraint(equalTo: cardTitleLabel.trailingAnchor),
            cardProgressBar.leadingAnchor.constraint(equalTo: cardTitleLabel.leadingAnchor),
            cardProgressBar.trailingAnchor.constraint(equalTo: cardTitleLabel.trailingAnchor),
            cardProgressBar.topAnchor.constraint(equalTo: cardTimeLabel.bottomAnchor, constant: 10),
            cardProgressBar.heightAnchor.constraint(equalToConstant: 10),
            cardProgressBar.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -10)
        ])
        cardContainer.heightAnchor.constraint(equalToConstant: 90).isActive = true
        stackView.addArrangedSubview(cardContainer)
        // cardContainer가 stackView 전체 너비를 차지하도록 제약 추가 (addArrangedSubview 이후!)
        cardContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true

        // --- 일정 리스트(스크롤) ---
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = innerStack
        innerStack.orientation = .vertical
        innerStack.spacing = 4
        innerStack.alignment = .leading
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        innerStack.autoresizingMask = [.width]
        NSLayoutConstraint.activate([
            innerStack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            innerStack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            innerStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            innerStack.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            innerStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        scrollHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 180)
        scrollHeightConstraint?.isActive = true
        stackView.addArrangedSubview(scrollView)

        // --- 더보기 버튼 ---
        moreButton.title = "더보기"
        moreButton.target = self
        moreButton.action = #selector(toggleMore)
        moreButton.isBordered = false
        moreButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        stackView.addArrangedSubview(moreButton)

        // --- +버튼 ---
        addButton.title = "+"
        addButton.target = self
        addButton.action = #selector(addScheduleTapped)
        addButton.setContentHuggingPriority(.required, for: .horizontal)
        addButton.setContentHuggingPriority(.required, for: .vertical)
        stackView.addArrangedSubview(addButton)

        // --- spacer ---
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacer)

        // --- 설정 버튼 ---
        settingsButton.title = "설정"
        settingsButton.target = self
        settingsButton.action = #selector(settingsTapped)
        settingsButton.font = NSFont.systemFont(ofSize: 13)
        stackView.addArrangedSubview(settingsButton)

        reloadSchedules()
    }
    
    @objc func toggleMore() {
        isExpanded.toggle()
        reloadSchedules()
    }
    
    @objc func addScheduleTapped() {
        let editor = ScheduleEditWindowController(schedule: nil)
        self.activeWindowController = editor
        editor.showWindow(nil)
    }
    
    @objc func settingsTapped() {
        // 설정 창 띄우기(임시)
        let alert = NSAlert()
        alert.messageText = "설정 기능은 준비 중입니다."
        alert.runModal()
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
        repButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        let label = NSTextField(labelWithString: "\(formatTime(start)) ~ \(formatTime(end)) \(schedule.title) \(percent)%")
        label.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = NSColor.labelColor
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        let editButton = NSButton(title: "✎", target: self, action: #selector(editScheduleTapped(_:)))
        editButton.tag = idx
        editButton.setButtonType(.momentaryPushIn)
        editButton.bezelStyle = .inline
        editButton.setContentHuggingPriority(.required, for: .horizontal)
        editButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        let deleteButton = NSButton(title: "🗑", target: self, action: #selector(deleteScheduleTapped(_:)))
        deleteButton.tag = idx
        deleteButton.setButtonType(.momentaryPushIn)
        deleteButton.bezelStyle = .inline
        deleteButton.setContentHuggingPriority(.required, for: .horizontal)
        deleteButton.setContentCompressionResistancePriority(.required, for: .horizontal)

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
        // --- 대표 일정/현재 일정 카드 ---
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        schedules = ScheduleStorage.shared.load()
        var cardSchedule: Schedule?
        if let rep = schedules.first(where: { $0.isRepresentative }) {
            cardSchedule = rep
        } else {
            // 현재 시간에 해당하는 일정
            cardSchedule = schedules.first(where: { schedule in
                var startComp = schedule.start
                startComp.year = today.year; startComp.month = today.month; startComp.day = today.day
                var endComp = schedule.end
                endComp.year = today.year; endComp.month = today.month; endComp.day = today.day
                guard let startDate = calendar.date(from: startComp), let endDate = calendar.date(from: endComp) else { return false }
                return now >= startDate && now <= endDate
            })
        }
        if let card = cardSchedule {
            cardTitleLabel.stringValue = card.title
            let start = calendar.date(from: { var c = card.start; c.year = today.year; c.month = today.month; c.day = today.day; return c }()) ?? now
            let end = calendar.date(from: { var c = card.end; c.year = today.year; c.month = today.month; c.day = today.day; return c }()) ?? now
            cardTimeLabel.stringValue = "\(formatTime(start)) ~ \(formatTime(end))"
            let progress = clampedProgress(from: now, start: start, end: end)
            cardProgressBar.doubleValue = progress
        } else {
            cardTitleLabel.stringValue = "대표 일정 없음"
            cardTimeLabel.stringValue = ""
            cardProgressBar.doubleValue = 0
        }

        // --- 일정 리스트 ---
        for subview in innerStack.arrangedSubviews { innerStack.removeArrangedSubview(subview); subview.removeFromSuperview() }
        let maxVisible = 4
        let showCount = isExpanded ? schedules.count : min(schedules.count, maxVisible)
        for (idx, schedule) in schedules.prefix(showCount).enumerated() {
            let now = Date()
            let calendar = Calendar.current
            let today = calendar.dateComponents([.year, .month, .day], from: now)
            guard let (start, end) = resolvedDateRange(from: schedule, on: today, using: calendar) else { continue }
            let progress = clampedProgress(from: now, start: start, end: end)
            let percent = Int(progress * 100)
            let item = makeScheduleStackItem(for: idx, schedule: schedule, percent: percent, progress: progress, start: start, end: end)
            innerStack.addArrangedSubview(item)
        }
        // 더보기 버튼 표시 여부
        moreButton.isHidden = schedules.count <= maxVisible
        moreButton.title = isExpanded ? "접기" : "더보기"
        // popover 크기 조정
        let itemHeight = 40
        let visibleCount = showCount
        // innerStack의 arrangedSubviews의 총 높이(간격 포함)로 scrollView 높이 계산
        let subviewCount = innerStack.arrangedSubviews.count
        let spacing = innerStack.spacing
        let scrollHeight: CGFloat = CGFloat(subviewCount) * CGFloat(itemHeight) + CGFloat(max(0, subviewCount-1)) * spacing
        let minHeight: CGFloat = 160
        let scrollFinalHeight = max(minHeight - 20, scrollHeight)
        scrollHeightConstraint?.constant = scrollFinalHeight // 기존 제약의 constant만 변경
        // 카드+여백+리스트+여백+add+여백+설정
        let totalHeight = 90 + 10 + scrollFinalHeight + 10 + 40 + 10 + 30 + 10
        baseView.setFrameSize(NSSize(width: 270, height: totalHeight))
        baseView.layoutSubtreeIfNeeded()
        // innerStack의 width를 scrollView.contentView에 강제 동기화
        innerStack.frame.size.width = scrollView.contentView.bounds.width
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
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if let popover = self.view.window?.windowController as? NSPopover {
            popover.delegate = self
        }
        reloadSchedules()
    }
    
    func popoverDidShow(_ notification: Notification) {
        reloadSchedules()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
