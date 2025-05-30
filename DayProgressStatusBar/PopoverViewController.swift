// Helper to create a divider line view
func makeDivider(height: CGFloat = 1.0, color: NSColor = .separatorColor) -> NSView {
    let line = NSView()
    line.translatesAutoresizingMaskIntoConstraints = false
    line.wantsLayer = true
    line.layer?.backgroundColor = color.cgColor
    line.heightAnchor.constraint(equalToConstant: height).isActive = true
    line.alphaValue = 0.3
    return line
}
//
//  PopeverViewController.swift
//  DayProgressStatusBar
//
//  Created by john on 5/26/25.
//

import Cocoa

class PopoverViewController : NSViewController, NSPopoverDelegate {
let todayProgressBar = NSProgressIndicator()
let monthProgressBar = NSProgressIndicator()
let yearProgressBar = NSProgressIndicator()
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
    baseView.frame = NSRect(x: 0, y: 0, width: width, height: 240)
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
        stackView.topAnchor.constraint(equalTo: baseView.topAnchor), // Remove extra top padding
        stackView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor, constant: -10)
    ])
    
    // --- Progress Bars (Today/Month/Year) ---
    let topStack = NSStackView()
    topStack.orientation = .vertical
    topStack.spacing = 6
    topStack.alignment = .leading
    
    func makeProgressRow(label: String, bar: NSProgressIndicator) -> NSStackView {
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.spacing = 8
        let titleLabel = NSTextField(labelWithString: label)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.alignment = .right
        titleLabel.frame.size.width = 40
        bar.minValue = 0
        bar.maxValue = 1
        bar.isIndeterminate = false
        bar.controlSize = .small
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.widthAnchor.constraint(equalToConstant: 180).isActive = true
        bar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        hStack.addArrangedSubview(titleLabel)
        hStack.addArrangedSubview(bar)
        return hStack
    }
    
    topStack.addArrangedSubview(makeProgressRow(label: "Today", bar: todayProgressBar))
    topStack.addArrangedSubview(makeProgressRow(label: "Month", bar: monthProgressBar))
    topStack.addArrangedSubview(makeProgressRow(label: "Year", bar: yearProgressBar))
    stackView.addArrangedSubview(topStack)
    stackView.addArrangedSubview(makeDivider())
    
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
    stackView.addArrangedSubview(makeDivider())
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
    stackView.addArrangedSubview(makeDivider())
    
    // --- 더보기 버튼 ---
    moreButton.title = "더보기"
    moreButton.target = self
    moreButton.action = #selector(toggleMore)
    moreButton.isBordered = false
    moreButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
    stackView.addArrangedSubview(moreButton)
    
    
    // --- spacer ---
    spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
    stackView.addArrangedSubview(spacer)
    
    // --- 설정 버튼 ---
    settingsButton.title = "Manage"
    settingsButton.target = self
    settingsButton.action = #selector(settingsTapped)
    settingsButton.font = NSFont.systemFont(ofSize: 13)
    // stackView.addArrangedSubview(settingsButton)

    // Custom Manage Row - macOS style interactive button row
    func makeManageRow() -> NSView {
        let row = NSButton()
        row.title = "Manage Schedules"
        row.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        row.bezelStyle = .recessed
        row.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        row.imagePosition = .imageLeading
        row.alignment = .left
        row.setButtonType(.momentaryPushIn)
        row.isBordered = true
        row.wantsLayer = true
        row.translatesAutoresizingMaskIntoConstraints = false
        row.action = #selector(settingsTapped)
        row.target = self
        row.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return row
    }

    stackView.addArrangedSubview(makeManageRow())
    
    reloadSchedules()
}

@objc func toggleMore() {
    isExpanded.toggle()
    reloadSchedules()
}


@objc func settingsTapped() {
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
    // 카드 없이, 배경 없는 StackView로 구성
    let vStack = NSStackView()
    vStack.orientation = .vertical
    vStack.spacing = 2
    vStack.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
    vStack.translatesAutoresizingMaskIntoConstraints = false

    // 상단: 대표 일정 별/제목/날짜
    let hStack = NSStackView()
    hStack.orientation = .horizontal
    hStack.spacing = 6
    hStack.alignment = .centerY
    hStack.translatesAutoresizingMaskIntoConstraints = false

    // 대표 일정 별
    let star = NSTextField(labelWithString: schedule.isRepresentative ? "★" : " ")
    star.font = NSFont.systemFont(ofSize: 15, weight: .bold)
    star.textColor = schedule.isRepresentative ? NSColor.systemOrange : .clear
    star.isBordered = false
    star.backgroundColor = .clear
    star.alignment = .center
    star.setContentHuggingPriority(.required, for: .horizontal)
    hStack.addArrangedSubview(star)

    // 제목
    let title = NSTextField(labelWithString: schedule.title)
    title.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
    title.textColor = .labelColor
    title.setContentHuggingPriority(.defaultLow, for: .horizontal)
    hStack.addArrangedSubview(title)

    // 날짜
    let dateLabel = NSTextField(labelWithString: DateFormatter.localizedString(from: start, dateStyle: .medium, timeStyle: .none))
    dateLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
    dateLabel.textColor = .secondaryLabelColor
    dateLabel.setContentHuggingPriority(.required, for: .horizontal)
    hStack.addArrangedSubview(dateLabel)

    vStack.addArrangedSubview(hStack)

    // 중간: 진행률/남은 시간
    let infoStack = NSStackView()
    infoStack.orientation = .horizontal
    infoStack.spacing = 8
    infoStack.alignment = .centerY
    infoStack.translatesAutoresizingMaskIntoConstraints = false

    // 퍼센트
    let percentLabel = NSTextField(labelWithString: "\(percent)%")
    percentLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
    percentLabel.textColor = .systemBlue
    percentLabel.setContentHuggingPriority(.required, for: .horizontal)
    infoStack.addArrangedSubview(percentLabel)

    // 남은 시간
    let leftSec = max(0, Int(end.timeIntervalSince(Date())))
    let leftHour = leftSec / 3600
    let leftMin = (leftSec % 3600) / 60
    let leftLabel = NSTextField(labelWithString: String(format: "%2d hr, %2d min", leftHour, leftMin))
    leftLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
    leftLabel.textColor = .secondaryLabelColor
    leftLabel.setContentHuggingPriority(.required, for: .horizontal)
    infoStack.addArrangedSubview(leftLabel)

    infoStack.addArrangedSubview(NSView()) // Spacer
    vStack.addArrangedSubview(infoStack)

    // 하단: 굵은 진행률 바
    let progressBar = NSView()
    progressBar.wantsLayer = true
    progressBar.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.18).cgColor
    progressBar.layer?.cornerRadius = 4
    progressBar.translatesAutoresizingMaskIntoConstraints = false
    progressBar.heightAnchor.constraint(equalToConstant: 10).isActive = true
    progressBar.widthAnchor.constraint(equalToConstant: 180).isActive = true

    let fillBar = NSView()
    fillBar.wantsLayer = true
    fillBar.layer?.backgroundColor = (schedule.isRepresentative ? NSColor.systemOrange : NSColor.systemBlue).cgColor
    fillBar.layer?.cornerRadius = 4
    fillBar.translatesAutoresizingMaskIntoConstraints = false
    progressBar.addSubview(fillBar)
    fillBar.heightAnchor.constraint(equalTo: progressBar.heightAnchor).isActive = true
    fillBar.widthAnchor.constraint(equalTo: progressBar.widthAnchor, multiplier: CGFloat(progress)).isActive = true
    fillBar.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor).isActive = true
    fillBar.topAnchor.constraint(equalTo: progressBar.topAnchor).isActive = true

    vStack.addArrangedSubview(progressBar)

    // 일정 간 구분선
    let divider = makeDivider(height: 1.0, color: NSColor.separatorColor.withAlphaComponent(0.08))
    vStack.addArrangedSubview(divider)

    vStack.widthAnchor.constraint(equalToConstant: 230).isActive = true
    return vStack
}

// Removed editScheduleTapped and deleteScheduleTapped: No longer needed since edit/delete buttons were removed.

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
    updateDateProgress()
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
    for subview in innerStack.arrangedSubviews {
        innerStack.removeArrangedSubview(subview)
        subview.removeFromSuperview()
    }
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
        item.setContentHuggingPriority(.required, for: .horizontal)
        item.widthAnchor.constraint(equalTo: innerStack.widthAnchor).isActive = true
    }
    // --- 하단 메뉴 ---
    let menuStack = NSStackView()
    menuStack.orientation = .vertical
    menuStack.spacing = 0
    menuStack.alignment = .leading
    menuStack.translatesAutoresizingMaskIntoConstraints = false

    // 커스텀 메뉴 항목: Manage Schedules
    let manageMenu = CustomMenuItemView(
        title: "Manage Schedules",
        image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil),
        action: { [weak self] in self?.settingsTapped() }
    )
    menuStack.addArrangedSubview(manageMenu)

    // 구분선
    let menuDivider = NSBox()
    menuDivider.boxType = .separator
    menuDivider.translatesAutoresizingMaskIntoConstraints = false
    menuDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true
    menuStack.addArrangedSubview(menuDivider)

    // 커스텀 메뉴 항목: Quit
    let quitMenu = CustomMenuItemView(
        title: "Quit",
        image: nil,
        action: { NSApp.terminate(nil) }
    )
    menuStack.addArrangedSubview(quitMenu)

    // 하단 메뉴를 innerStack에 추가
    let divider = makeDivider(height: 1.0, color: NSColor.separatorColor.withAlphaComponent(0.2))
    innerStack.addArrangedSubview(divider)
    innerStack.addArrangedSubview(menuStack)
    // 더보기 버튼 표시 여부
    moreButton.isHidden = schedules.count <= maxVisible
    moreButton.title = isExpanded ? "접기" : "더보기"
    // popover 크기 조정
    let itemHeight = 40
    // innerStack의 arrangedSubviews의 총 높이(간격 포함)로 scrollView 높이 계산
    let subviewCount = innerStack.arrangedSubviews.count
    let spacing = innerStack.spacing
    let scrollHeight: CGFloat = CGFloat(subviewCount) * CGFloat(itemHeight) + CGFloat(max(0, subviewCount-1)) * spacing
    let minHeight: CGFloat = 160
    let scrollFinalHeight = max(minHeight - 20, scrollHeight)
    // scrollView 높이 capped 처리
    let cappedScrollHeight = min(scrollFinalHeight, 180)
    scrollHeightConstraint?.constant = cappedScrollHeight

    // 카드+여백+리스트+여백+설정 (버튼 intrinsicContentSize 사용)
    let totalHeight = 90 + 10 + cappedScrollHeight + 10 + settingsButton.intrinsicContentSize.height + 20
    // baseView.setFrameSize(NSSize(width: 270, height: totalHeight))
    // view.window?.setContentSize(NSSize(width: 270, height: totalHeight))
    baseView.layoutSubtreeIfNeeded()
    stackView.layoutSubtreeIfNeeded()
    // innerStack의 width를 scrollView.contentView에 강제 동기화
    // innerStack.frame.size.width = scrollView.contentView.bounds.width
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
    // Removed redundant reloadSchedules() to prevent popover resizing on every show.
}

func popoverDidShow(_ notification: Notification) {
    reloadSchedules()
}

deinit {
    NotificationCenter.default.removeObserver(self)
}

func updateDateProgress() {
    let now = Date()
    let calendar = Calendar.current
    
    // Today
    let startDay = calendar.startOfDay(for: now)
    let endDay = calendar.date(byAdding: .day, value: 1, to: startDay)!
    let todayProgress = now.timeIntervalSince(startDay) / endDay.timeIntervalSince(startDay)
    
    // Month
    let comps = calendar.dateComponents([.year, .month], from: now)
    let startMonth = calendar.date(from: comps)!
    let range = calendar.range(of: .day, in: .month, for: now)!
    let daysInMonth = Double(range.count)
    let dayOfMonth = Double(calendar.component(.day, from: now) - 1)
    let secondsToday = now.timeIntervalSince(calendar.startOfDay(for: now))
    let monthProgress = (dayOfMonth + secondsToday / 86400.0) / daysInMonth
    
    // Year
    let year = calendar.component(.year, from: now)
    let startYear = calendar.date(from: DateComponents(year: year))!
    let endYear = calendar.date(from: DateComponents(year: year + 1))!
    let yearProgress = now.timeIntervalSince(startYear) / endYear.timeIntervalSince(startYear)
    
    todayProgressBar.doubleValue = min(max(todayProgress, 0), 1)
    monthProgressBar.doubleValue = min(max(monthProgress, 0), 1)
    yearProgressBar.doubleValue = min(max(yearProgress, 0), 1)
}
}

// macOS 메뉴 스타일 커스텀 메뉴 항목 뷰
class CustomMenuItemView: NSView {
    let action: () -> Void
    let label = NSTextField()
    let iconView = NSImageView()
    var isHovered = false {
        didSet { updateStyle() }
    }
    init(title: String, image: NSImage?, action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        // Stack
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.spacing = 8
        hStack.alignment = .centerY
        hStack.translatesAutoresizingMaskIntoConstraints = false
        // Icon
        if let image = image {
            iconView.image = image
            iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            iconView.contentTintColor = .labelColor
            hStack.addArrangedSubview(iconView)
        }
        // Label
        label.stringValue = title
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .left
        hStack.addArrangedSubview(label)
        addSubview(hStack)
        hStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12).isActive = true
        hStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12).isActive = true
        hStack.topAnchor.constraint(equalTo: topAnchor, constant: 2).isActive = true
        hStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2).isActive = true
        // Tracking
        let tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(tracking)
        // 클릭 이벤트
        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        addGestureRecognizer(click)
        updateStyle()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    @objc func clicked() { action() }
    func updateStyle() {
        if isHovered {
            layer?.backgroundColor = NSColor.systemBlue.cgColor
            label.textColor = .white
            iconView.contentTintColor = .white
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            label.textColor = .labelColor
            iconView.contentTintColor = .labelColor
        }
    }
}
