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
    
    var scheduleManager: ScheduleManagerWindowController?
    
    var displayPercent: Int = 0
    var percentAnimationTimer: Timer?
    var targetPercent: Int = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "0%"
        
        // 상단바 클릭 이벤트를 NSMenu로 변경
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showMenu(_:))
        
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
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: Notification.Name("AppLanguageChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showScheduleTitleChanged), name: Notification.Name("ShowScheduleTitleChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(statusBarIconStyleChanged), name: Notification.Name("StatusBarIconStyleChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showTimeLeftInsteadOfPercentChanged), name: Notification.Name("ShowTimeLeftInsteadOfPercentChanged"), object: nil)
    }
    
    @objc func scheduleListDidUpdate() {
        updateStatusBarPercent()
    }
    
    func updateStatusBarPercent() {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        let allSchedules = schedules
        let showTitle = UserDefaults.standard.bool(forKey: "ShowScheduleTitle")
        let iconStyle = UserDefaults.standard.string(forKey: "StatusBarIconStyle") ?? "none"
        let showTimeLeft = UserDefaults.standard.bool(forKey: "ShowTimeLeftInsteadOfPercent")
        var percent: Int = 0
        var titleText: String = ""
        var timeLeftText: String? = nil
        // 대표 일정 우선
        if let rep = allSchedules.first(where: { $0.isRepresentative }) {
            var startComp = rep.start
            var endComp = rep.end
            startComp.year = today.year; startComp.month = today.month; startComp.day = today.day
            endComp.year = today.year; endComp.month = today.month; endComp.day = today.day
            let start = calendar.date(from: startComp) ?? now
            let end = calendar.date(from: endComp) ?? now
            percent = max(0, min(100, Int((now.timeIntervalSince(start) / max(1, end.timeIntervalSince(start))) * 100)))
            if showTimeLeft {
                let remain = max(0, end.timeIntervalSince(now))
                timeLeftText = self.formatTimeLeft(remain)
                titleText = showTitle ? "\(rep.title) \(timeLeftText!)" : "\(timeLeftText!)"
            } else {
                titleText = showTitle ? "\(rep.title) \(percent)%" : "\(percent)%"
            }
        } else {
            // 현재 시간 겹치는 일정 중 가장 빠른 것
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
                let schedule = selected.0
                var startComp = schedule.start
                var endComp = schedule.end
                startComp.year = today.year; startComp.month = today.month; startComp.day = today.day
                endComp.year = today.year; endComp.month = today.month; endComp.day = today.day
                let start = calendar.date(from: startComp) ?? now
                let end = calendar.date(from: endComp) ?? now
                percent = max(0, min(100, Int((now.timeIntervalSince(start) / max(1, end.timeIntervalSince(start))) * 100)))
                if showTimeLeft {
                    let remain = max(0, end.timeIntervalSince(now))
                    timeLeftText = self.formatTimeLeft(remain)
                    titleText = showTitle ? "\(schedule.title) \(timeLeftText!)" : "\(timeLeftText!)"
                } else {
                    titleText = showTitle ? "\(schedule.title) \(percent)%" : "\(percent)%"
                }
            } else {
                // 일정 없거나 해당 없음: 오늘의 %
                let startDay = calendar.startOfDay(for: now)
                let endDay = calendar.date(byAdding: .day, value: 1, to: startDay)!
                let todayProgress = now.timeIntervalSince(startDay) / endDay.timeIntervalSince(startDay)
                percent = Int(todayProgress * 100)
                if showTimeLeft {
                    let remain = max(0, endDay.timeIntervalSince(now))
                    timeLeftText = self.formatTimeLeft(remain)
                    titleText = showTitle ? "Day - \(timeLeftText!)" : "\(timeLeftText!)"
                } else {
                    titleText = showTitle ? "Day - \(percent)%" : "\(percent)%"
                }
            }
        }
        self.targetPercent = percent
        self.animateStatusBarIcon(to: percent, titleText: titleText, iconStyle: iconStyle, showTimeLeft: showTimeLeft)
    }
    
    @objc func showMenu(_ sender: AnyObject?) {
        let menu = NSMenu()
        // 1. 일/월/년 % + ProgressBar
        let progressItem = NSMenuItem()
        progressItem.view = makeDateProgressView()
        menu.addItem(progressItem)
        // 2. 대표 일정
        menu.addItem(NSMenuItem.separator())
        let repItem = NSMenuItem()
        repItem.view = makeRepresentativeScheduleView()
        menu.addItem(repItem)
        // 3. 일정 리스트
        menu.addItem(NSMenuItem.separator())
        let schedules = ScheduleStorage.shared.load()
        if schedules.isEmpty {
            let emptyItem = NSMenuItem(title: LocalizedManager.shared.localized("No schedules registered."), action: nil, keyEquivalent: "")
            menu.addItem(emptyItem)
        } else {
            for (idx, schedule) in schedules.enumerated() {
                let item = NSMenuItem()
                item.view = makeScheduleListItemView(schedule: schedule, index: idx)
                menu.addItem(item)
            }
        }
        // 4. Manage Schedule
        menu.addItem(NSMenuItem.separator())
        let manageItem = NSMenuItem(title: LocalizedManager.shared.localized("Manage Schedules"), action: #selector(openScheduleManager), keyEquivalent: "")
        manageItem.target = self
        menu.addItem(manageItem)
        // 5. Settings
        let settingsItem = NSMenuItem(title: LocalizedManager.shared.localized("Settings"), action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        // 6. Quit
        let quitItem = NSMenuItem(title: LocalizedManager.shared.localized("Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { self.statusItem.menu = nil }
    }

    // 1단락: 일/월/년 % + ProgressBar 커스텀 뷰 (실제 데이터 연동)
    func makeDateProgressView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 110))
        let calendar = Calendar.current
        let now = Date()
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
        // --- UI ---
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        // Today
        let todayLabel = NSTextField(labelWithString: String(format: "%@  %2d%%", LocalizedManager.shared.localized("Today"), Int(todayProgress * 100)))
        todayLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let todayBar = NSProgressIndicator()
        todayBar.minValue = 0; todayBar.maxValue = 1; todayBar.doubleValue = todayProgress
        todayBar.isIndeterminate = false
        todayBar.controlSize = .small
        todayBar.style = .bar
        todayBar.translatesAutoresizingMaskIntoConstraints = false
        todayBar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        todayBar.widthAnchor.constraint(equalToConstant: 180).isActive = true
        // Month
        let monthLabel = NSTextField(labelWithString: String(format: "%@  %2d%%", LocalizedManager.shared.localized("Month"), Int(monthProgress * 100)))
        monthLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let monthBar = NSProgressIndicator()
        monthBar.minValue = 0; monthBar.maxValue = 1; monthBar.doubleValue = monthProgress
        monthBar.isIndeterminate = false
        monthBar.controlSize = .small
        monthBar.style = .bar
        monthBar.translatesAutoresizingMaskIntoConstraints = false
        monthBar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        monthBar.widthAnchor.constraint(equalToConstant: 180).isActive = true
        // Year
        let yearLabel = NSTextField(labelWithString: String(format: "%@   %2d%%", LocalizedManager.shared.localized("Year"), Int(yearProgress * 100)))
        yearLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let yearBar = NSProgressIndicator()
        yearBar.minValue = 0; yearBar.maxValue = 1; yearBar.doubleValue = yearProgress
        yearBar.isIndeterminate = false
        yearBar.controlSize = .small
        yearBar.style = .bar
        yearBar.translatesAutoresizingMaskIntoConstraints = false
        yearBar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        yearBar.widthAnchor.constraint(equalToConstant: 180).isActive = true
        // Add to stack
        stack.addArrangedSubview(todayLabel)
        stack.addArrangedSubview(todayBar)
        stack.addArrangedSubview(monthLabel)
        stack.addArrangedSubview(monthBar)
        stack.addArrangedSubview(yearLabel)
        stack.addArrangedSubview(yearBar)
        view.addSubview(stack)
        stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10).isActive = true
        stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6).isActive = true
        return view
    }

    // 2단락: 대표 일정 뷰
    func makeRepresentativeScheduleView() -> NSView {
        let schedules = ScheduleStorage.shared.load()
        guard let rep = schedules.first(where: { $0.isRepresentative }) else {
            let label = NSTextField(labelWithString: LocalizedManager.shared.localized("No representative schedule"))
            label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.backgroundColor = .clear
            label.isBordered = false
            label.alignment = .left
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 22))
            label.frame = NSRect(x: 12, y: 1, width: 200, height: 20)
            view.addSubview(label)
            return view
        }
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        var startComp = rep.start
        var endComp = rep.end
        startComp.year = today.year; startComp.month = today.month; startComp.day = today.day
        endComp.year = today.year; endComp.month = today.month; endComp.day = today.day
        let start = calendar.date(from: startComp) ?? now
        let end = calendar.date(from: endComp) ?? now
        let percent = max(0, min(100, Int((now.timeIntervalSince(start) / max(1, end.timeIntervalSince(start))) * 100)))
        let label = NSTextField(labelWithString: "★  \(rep.title)  \(percent)%")
        label.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .systemOrange
        label.backgroundColor = .clear
        label.isBordered = false
        label.alignment = .left
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 22))
        label.frame = NSRect(x: 12, y: 1, width: 200, height: 20)
        view.addSubview(label)
        return view
    }

    // 3단락: 일정 리스트 아이템 뷰 (퍼센트, ProgressBar, 일정명, 시간, 핀셋)
    func makeScheduleListItemView(schedule: Schedule, index: Int) -> NSView {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        var startComp = schedule.start
        var endComp = schedule.end
        startComp.year = today.year; startComp.month = today.month; startComp.day = today.day
        endComp.year = today.year; endComp.month = today.month; endComp.day = today.day
        let start = calendar.date(from: startComp) ?? now
        let end = calendar.date(from: endComp) ?? now
        let progress: Double
        if now <= start {
            progress = 0
        } else if now >= end {
            progress = 1
        } else {
            let duration = end.timeIntervalSince(start)
            progress = duration > 0 ? now.timeIntervalSince(start) / duration : 0
        }
        let percent = Int(progress * 100)
        let isRep = schedule.isRepresentative
        return ScheduleMenuItemView(schedule: schedule, index: index, percent: percent, start: start, end: end, isRep: isRep, target: self, progress: progress)
    }

    // 핀셋 클릭 시 대표 일정 토글
    @objc func toggleRepresentative(_ sender: NSButton) {
        let idx = sender.tag
        var schedules = ScheduleStorage.shared.load()
        let isCurrentlyRep = schedules[idx].isRepresentative
        for i in 0..<schedules.count { schedules[i].isRepresentative = false }
        if !isCurrentlyRep {
            schedules[idx].isRepresentative = true
        }
        ScheduleStorage.shared.save(schedules)
        NotificationCenter.default.post(name: .scheduleListUpdated, object: nil)
        
        // 메뉴를 닫고 다시 열어 UI 갱신
        DispatchQueue.main.async {
            self.statusItem.menu?.cancelTracking()
            self.showMenu(nil)
        }
    }

    // formatTime을 static으로도 제공
    static func formatTimeStatic(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    @objc func openScheduleManager() {
        if scheduleManager == nil {
            scheduleManager = ScheduleManagerWindowController()
        }
        if let window = scheduleManager?.window, let button = statusItem.button {
            let buttonRect = button.window?.convertToScreen(button.frame) ?? .zero
            let winSize = window.frame.size
            let origin = NSPoint(x: buttonRect.origin.x + buttonRect.width/2 - winSize.width/2, y: buttonRect.origin.y - winSize.height - 8)
            window.setFrameOrigin(origin)
        }
        scheduleManager?.showWindow(nil)
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController()
            settingsWindow?.onLanguageChanged = { [weak self] lang in
                self?.applyLanguage(lang)
            }
        }
        if let window = settingsWindow?.window, let button = statusItem.button {
            let buttonRect = button.window?.convertToScreen(button.frame) ?? .zero
            let winSize = window.frame.size
            let origin = NSPoint(x: buttonRect.origin.x + buttonRect.width/2 - winSize.width/2, y: buttonRect.origin.y - winSize.height - 8)
            window.setFrameOrigin(origin)
        }
        settingsWindow?.showWindow(nil)
    }

    var settingsWindow: SettingsWindowController?

    func applyLanguage(_ lang: String) {
        // 실제 언어 변경 로직은 여기서 처리 (UserDefaults 등 활용)
        // 예시: UserDefaults.standard.set(lang, forKey: "AppLanguage")
        // 그리고 NotificationCenter 등으로 전체 UI 갱신
    }

    @objc func languageChanged() {
        showMenu(nil)
    }

    @objc func showScheduleTitleChanged() {
        updateStatusBarPercent()
    }

    @objc func statusBarIconStyleChanged() {
        updateStatusBarPercent()
    }

    @objc func showTimeLeftInsteadOfPercentChanged() {
        updateStatusBarPercent()
    }

    // 진행률 배터리 아이콘 그리기
    func drawBatteryIcon(percent: Int) -> NSImage? {
        let size = NSSize(width: 22, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(x: 1, y: 2, width: 18, height: 8)
        let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
        NSColor.gray.setStroke()
        path.lineWidth = 1.2
        path.stroke()
        // 배터리 머리
        let head = NSRect(x: 19, y: 4, width: 2, height: 4)
        let headPath = NSBezierPath(roundedRect: head, xRadius: 1, yRadius: 1)
        NSColor.gray.setFill()
        headPath.fill()
        // 채워진 부분
        let fillWidth = CGFloat(percent) * 16 / 100
        let fillRect = NSRect(x: 2, y: 3, width: fillWidth, height: 6)
        let fillColor = percent < 20 ? NSColor.systemRed : NSColor.systemGreen
        fillColor.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: 1, yRadius: 1).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    // 진행률 원 아이콘 그리기
    func drawCircleIcon(percent: Int) -> NSImage? {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        let center = CGPoint(x: 7, y: 7)
        let radius: CGFloat = 6
        let startAngle: CGFloat = 90
        let endAngle: CGFloat = 90 - 360 * CGFloat(percent) / 100
        // 배경 원
        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        NSColor.gray.withAlphaComponent(0.3).setStroke()
        bgPath.lineWidth = 2
        bgPath.stroke()
        // 진행률 원
        let fgPath = NSBezierPath()
        fgPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        let fillColor = percent < 20 ? NSColor.systemRed : NSColor.systemBlue
        fillColor.setStroke()
        fgPath.lineWidth = 2.5
        fgPath.stroke()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    func animateStatusBarIcon(to percent: Int, titleText: String, iconStyle: String, showTimeLeft: Bool) {
        percentAnimationTimer?.invalidate()
        let start = displayPercent
        let end = percent
        let duration: Double = 0.35
        let frameCount = 15
        if start == end || showTimeLeft {
            DispatchQueue.main.async {
                self.statusItem.button?.title = titleText
                switch iconStyle {
                case "battery":
                    self.statusItem.button?.image = self.drawBatteryIcon(percent: end)
                case "circle":
                    self.statusItem.button?.image = self.drawCircleIcon(percent: end)
                default:
                    self.statusItem.button?.image = nil
                }
            }
            return
        }
        var currentFrame = 0
        percentAnimationTimer = Timer.scheduledTimer(withTimeInterval: duration/Double(frameCount), repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            currentFrame += 1
            let progress = min(1.0, Double(currentFrame)/Double(frameCount))
            let value = Int(round(Double(start) + (Double(end-start) * progress)))
            self.displayPercent = value
            DispatchQueue.main.async {
                self.statusItem.button?.title = titleText.replacingOccurrences(of: "\\d+%", with: "\(value)%", options: .regularExpression)
                switch iconStyle {
                case "battery":
                    self.statusItem.button?.image = self.drawBatteryIcon(percent: value)
                case "circle":
                    self.statusItem.button?.image = self.drawCircleIcon(percent: value)
                default:
                    self.statusItem.button?.image = nil
                }
            }
            if currentFrame >= frameCount {
                t.invalidate()
                self.displayPercent = end
            }
        }
    }

    func formatTimeLeft(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let lm = LocalizedManager.shared
        if hours > 0 {
            let hourKey = hours == 1 ? "hour left" : "hours left"
            let minKey = minutes == 1 ? "minute left" : "minutes left"
            if minutes > 0 {
                return "\(hours) \(lm.localized(hourKey)), \(minutes) \(lm.localized(minKey))"
            } else {
                return "\(hours) \(lm.localized(hourKey))"
            }
        } else {
            let minKey = minutes == 1 ? "minute left" : "minutes left"
            return "\(minutes) \(lm.localized(minKey))"
        }
    }
}

// --- 일정 리스트 아이템 뷰 개선: hover 효과, 여백, 폰트, 색상 등 macOS 메뉴 스타일 반영 ---
class ScheduleMenuItemView: NSView {
    let pinButton: NSButton
    let titleLabel: NSTextField
    let timeLabel: NSTextField
    let percentLabel: NSTextField
    let bar: NSProgressIndicator
    let hoverLayer = CALayer()
    var isHovered = false { didSet { updateStyle() } }
    init(schedule: Schedule, index: Int, percent: Int, start: Date, end: Date, isRep: Bool, target: AnyObject, progress: Double) {
        pinButton = NSButton()
        titleLabel = NSTextField(labelWithString: schedule.title)
        timeLabel = NSTextField(labelWithString: String(format: "%@ ~ %@", AppDelegate.formatTimeStatic(start), AppDelegate.formatTimeStatic(end)))
        percentLabel = NSTextField(labelWithString: "\(percent)%")
        bar = NSProgressIndicator()
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 38))
        wantsLayer = true
        layer?.cornerRadius = 6
        // Hover Layer
        hoverLayer.backgroundColor = NSColor.systemBlue.cgColor
        hoverLayer.opacity = 0
        hoverLayer.cornerRadius = 6
        hoverLayer.frame = bounds
        layer?.addSublayer(hoverLayer)
        // 핀셋
        pinButton.bezelStyle = .inline
        pinButton.isBordered = false
        pinButton.title = ""
        pinButton.image = NSImage(systemSymbolName: isRep ? "pin.fill" : "pin", accessibilityDescription: nil)
        pinButton.imagePosition = .imageOnly
        pinButton.frame = NSRect(x: 4, y: 12, width: 16, height: 16)
        pinButton.target = target
        pinButton.action = #selector(AppDelegate.toggleRepresentative(_:))
        pinButton.tag = index
        addSubview(pinButton)
        // 일정명
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.backgroundColor = .clear
        titleLabel.isBordered = false
        titleLabel.alignment = .left
        titleLabel.frame = NSRect(x: 28, y: 18, width: 120, height: 16)
        addSubview(titleLabel)
        // 시간
        timeLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.backgroundColor = .clear
        timeLabel.isBordered = false
        timeLabel.alignment = .left
        timeLabel.frame = NSRect(x: 28, y: 2, width: 120, height: 14)
        addSubview(timeLabel)
        // 퍼센트
        percentLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        percentLabel.textColor = .systemBlue
        percentLabel.backgroundColor = .clear
        percentLabel.isBordered = false
        percentLabel.alignment = .right
        percentLabel.frame = NSRect(x: 160, y: 18, width: 40, height: 16)
        addSubview(percentLabel)
        // ProgressBar
        bar.frame = NSRect(x: 160, y: 4, width: 40, height: 8)
        bar.minValue = 0; bar.maxValue = 1; bar.doubleValue = progress
        bar.isIndeterminate = false
        bar.controlSize = .small
        bar.style = .bar
        addSubview(bar)
        // Tracking
        let tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(tracking)
        updateStyle()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func layout() {
        super.layout()
        hoverLayer.frame = bounds
    }
    func updateStyle() {
        if isHovered {
            hoverLayer.opacity = 1
            titleLabel.textColor = .white
            timeLabel.textColor = NSColor.white.withAlphaComponent(0.7)
            percentLabel.textColor = .white
            pinButton.contentTintColor = .white
        } else {
            hoverLayer.opacity = 0
            titleLabel.textColor = .labelColor
            timeLabel.textColor = .secondaryLabelColor
            percentLabel.textColor = .systemBlue
            pinButton.contentTintColor = .labelColor
        }
    }
}
