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
    
    // --- Centralized State ---
    var dayProgress: Double = 0
    var monthProgress: Double = 0
    var yearProgress: Double = 0
    var currentScheduleInfo: (schedule: Schedule?, percent: Int, titleText: String) = (nil, 0, "0%")
    var allSchedulesInfo: [(schedule: Schedule, percent: Int, progress: Double, start: Date, end: Date)] = []
    
    // --- Animation State ---
    var displayPercent: Int = 0
    var percentAnimationTimer: Timer?
    var animationID: Int = 0
    var lastDisplayedScheduleTitle: String?
    
    var scheduleManager: ScheduleManagerWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "0%"
        
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showMenu(_:))
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            _ in self.updateAllProgress()
        }
        updateAllProgress()
        
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleListDidUpdate), name: .scheduleListUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: Notification.Name("AppLanguageChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: Notification.Name("ShowScheduleTitleChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: Notification.Name("StatusBarIconStyleChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: Notification.Name("ShowTimeLeftInsteadOfPercentChanged"), object: nil)
    }
    
    @objc func scheduleListDidUpdate() {
        updateAllProgress()
        if statusItem.menu != nil {
            statusItem.menu?.cancelTracking()
            showMenu(nil)
        }
    }
    
    @objc func settingsChanged() {
        updateAllProgress()
    }
    
    @objc func updateAllProgress() {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        let allSchedules = ScheduleStorage.shared.load()

        // --- Day/Month/Year Progress Calculation (with rounding) ---
        let startDay = calendar.startOfDay(for: now)
        let endDay = calendar.date(byAdding: .day, value: 1, to: startDay)!
        self.dayProgress = now.timeIntervalSince(startDay) / endDay.timeIntervalSince(startDay)
        let comps = calendar.dateComponents([.year, .month], from: now)
        let startMonth = calendar.date(from: comps)!
        let rangeDays = calendar.range(of: .day, in: .month, for: now)!
        let daysInMonth = Double(rangeDays.count)
        let dayOfMonth = Double(calendar.component(.day, from: now) - 1)
        let secondsToday = now.timeIntervalSince(calendar.startOfDay(for: now))
        self.monthProgress = (dayOfMonth + secondsToday / 86400.0) / daysInMonth
        let year = calendar.component(.year, from: now)
        let startYear = calendar.date(from: DateComponents(year: year))!
        let endYear = calendar.date(from: DateComponents(year: year + 1))!
        self.yearProgress = now.timeIntervalSince(startYear) / endYear.timeIntervalSince(startYear)

        // --- Single Source of Truth: All Schedules Info Calculation (with Rounding) ---
        self.allSchedulesInfo = allSchedules.map { schedule in
            var startComp = schedule.start
            var endComp = schedule.end
            startComp.year = today.year; startComp.month = today.month; startComp.day = today.day
            endComp.year = today.year; endComp.month = today.month; endComp.day = today.day
            let start = calendar.date(from: startComp) ?? now
            let end = calendar.date(from: endComp) ?? now
            let progress: Double
            if now <= start { progress = 0 }
            else if now >= end { progress = 1 }
            else {
                let duration = end.timeIntervalSince(start)
                progress = duration > 0 ? now.timeIntervalSince(start) / duration : 0
            }
            return (schedule, Int((progress * 100).rounded()), progress, start, end)
        }
        
        // --- Determine Current Schedule for Status Bar from the Single Source of Truth ---
        let showTitle = UserDefaults.standard.bool(forKey: "ShowScheduleTitle")
        let showTimeLeft = UserDefaults.standard.bool(forKey: "ShowTimeLeftInsteadOfPercent")
        
        var activeScheduleInfo = allSchedulesInfo.first { $0.schedule.isRepresentative }
        if activeScheduleInfo == nil {
            let activeCandidates = allSchedulesInfo.filter { info in
                let start = info.start
                let end = info.end
                return now >= start && now <= end
            }
            activeScheduleInfo = activeCandidates.min(by: { $0.start < $1.start })
        }

        if let info = activeScheduleInfo {
            let percent = info.percent
            let title: String
            if showTimeLeft {
                let remain = max(0, info.end.timeIntervalSince(now))
                let timeLeftText = self.formatTimeLeft(remain)
                title = showTitle ? "\(info.schedule.title) \(timeLeftText)" : timeLeftText
            } else {
                title = showTitle ? "\(info.schedule.title) \(percent)%" : "\(percent)%"
            }
            self.currentScheduleInfo = (info.schedule, percent, title)
        } else {
            // No active schedule, use Day progress as fallback
            let percent = Int((self.dayProgress * 100).rounded())
            let title: String
            if showTimeLeft {
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
                let remain = max(0, endOfDay.timeIntervalSince(now))
                let timeLeftText = self.formatTimeLeft(remain)
                title = showTitle ? "Day - \(timeLeftText)" : timeLeftText
            } else {
                title = showTitle ? "Day - \(percent)%" : "\(percent)%"
            }
            self.currentScheduleInfo = (nil, percent, title)
        }

        updateStatusBarDisplay()
    }
    
    func updateStatusBarDisplay() {
        let iconStyle = UserDefaults.standard.string(forKey: "StatusBarIconStyle") ?? "none"
        let showTimeLeft = UserDefaults.standard.bool(forKey: "ShowTimeLeftInsteadOfPercent")

        self.animateStatusBarIcon(
            to: self.currentScheduleInfo.percent,
            forSchedule: self.currentScheduleInfo.schedule,
            titleText: self.currentScheduleInfo.titleText,
            iconStyle: iconStyle,
            showTimeLeft: showTimeLeft
        )
    }
    
    @objc func showMenu(_ sender: AnyObject?) {
        let menu = NSMenu()
        let progressItem = NSMenuItem()
        progressItem.view = makeDateProgressView()
        menu.addItem(progressItem)
        menu.addItem(NSMenuItem.separator())
        let repItem = NSMenuItem()
        repItem.view = makeRepresentativeScheduleView()
        menu.addItem(repItem)
        menu.addItem(NSMenuItem.separator())

        if allSchedulesInfo.isEmpty {
            let emptyItem = NSMenuItem(title: LocalizedManager.shared.localized("No schedules registered."), action: nil, keyEquivalent: "")
            menu.addItem(emptyItem)
        } else {
            for (idx, info) in allSchedulesInfo.enumerated() {
                let item = NSMenuItem()
                item.view = makeScheduleListItemView(scheduleInfo: info, index: idx)
                menu.addItem(item)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        let manageItem = NSMenuItem(title: LocalizedManager.shared.localized("Manage Schedules"), action: #selector(openScheduleManager), keyEquivalent: "")
        manageItem.target = self
        menu.addItem(manageItem)
        let settingsItem = NSMenuItem(title: LocalizedManager.shared.localized("Settings"), action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let quitItem = NSMenuItem(title: LocalizedManager.shared.localized("Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        statusItem.menu = menu
        if sender != nil {
            statusItem.button?.performClick(nil)
            DispatchQueue.main.async { self.statusItem.menu = nil }
        }
    }

    func makeDateProgressView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 110))
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        let todayLabel = NSTextField(labelWithString: String(format: "%@  %2d%%", LocalizedManager.shared.localized("Today"), Int((self.dayProgress * 100).rounded())))
        todayLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let todayBar = NSProgressIndicator()
        todayBar.minValue = 0.0; todayBar.maxValue = 1.0
        todayBar.doubleValue = self.dayProgress
        todayBar.isIndeterminate = false; todayBar.controlSize = .small; todayBar.style = .bar
        todayBar.translatesAutoresizingMaskIntoConstraints = false
        todayBar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        todayBar.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let monthLabel = NSTextField(labelWithString: String(format: "%@  %2d%%", LocalizedManager.shared.localized("Month"), Int((self.monthProgress * 100).rounded())))
        monthLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let monthBar = NSProgressIndicator()
        monthBar.minValue = 0.0; monthBar.maxValue = 1.0
        monthBar.doubleValue = self.monthProgress
        monthBar.isIndeterminate = false; monthBar.controlSize = .small; monthBar.style = .bar
        monthBar.translatesAutoresizingMaskIntoConstraints = false
        monthBar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        monthBar.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let yearLabel = NSTextField(labelWithString: String(format: "%@   %2d%%", LocalizedManager.shared.localized("Year"), Int((self.yearProgress * 100).rounded())))
        yearLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let yearBar = NSProgressIndicator()
        yearBar.minValue = 0.0; yearBar.maxValue = 1.0
        yearBar.doubleValue = self.yearProgress
        yearBar.isIndeterminate = false; yearBar.controlSize = .small; yearBar.style = .bar
        yearBar.translatesAutoresizingMaskIntoConstraints = false
        yearBar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        yearBar.widthAnchor.constraint(equalToConstant: 180).isActive = true

        stack.addArrangedSubview(todayLabel); stack.addArrangedSubview(todayBar)
        stack.addArrangedSubview(monthLabel); stack.addArrangedSubview(monthBar)
        stack.addArrangedSubview(yearLabel); stack.addArrangedSubview(yearBar)
        view.addSubview(stack)
        stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10).isActive = true
        stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6).isActive = true
        return view
    }

    func makeRepresentativeScheduleView() -> NSView {
        guard let repInfo = allSchedulesInfo.first(where: { $0.schedule.isRepresentative }) else {
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
        
        let label = NSTextField(labelWithString: "★  \(repInfo.schedule.title)  \(repInfo.percent)%")
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

    func makeScheduleListItemView(scheduleInfo: (schedule: Schedule, percent: Int, progress: Double, start: Date, end: Date), index: Int) -> NSView {
        return ScheduleMenuItemView(schedule: scheduleInfo.schedule, index: index, percent: scheduleInfo.percent, start: scheduleInfo.start, end: scheduleInfo.end, isRep: scheduleInfo.schedule.isRepresentative, target: self, progress: scheduleInfo.progress)
    }

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
    }

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
    }

    @objc func languageChanged() {
        updateAllProgress()
        showMenu(nil)
    }
    
    func animateStatusBarIcon(to percent: Int, forSchedule schedule: Schedule?, titleText: String, iconStyle: String, showTimeLeft: Bool) {
        let newScheduleTitle = schedule?.title

        // --- Correctness First: If schedule changed, SNAP to new value ---
        if newScheduleTitle != self.lastDisplayedScheduleTitle || showTimeLeft {
            percentAnimationTimer?.invalidate()
            self.displayPercent = percent
            self.lastDisplayedScheduleTitle = newScheduleTitle
            
            DispatchQueue.main.async {
                self.statusItem.button?.title = titleText
                switch iconStyle {
                case "battery": self.statusItem.button?.image = self.drawBatteryIcon(percent: percent)
                case "circle": self.statusItem.button?.image = self.drawCircleIcon(percent: percent)
                default: self.statusItem.button?.image = nil
                }
            }
            return
        }
        
        // --- Animate only if the schedule is the same ---
        percentAnimationTimer?.invalidate()
        animationID += 1
        let currentAnimationID = animationID
        
        let start = displayPercent
        let end = percent
        let duration: Double = 0.35
        let frameCount = 15
        
        if start == end {
            // Even if value is same, settings like iconStyle might have changed
            DispatchQueue.main.async {
                self.statusItem.button?.title = titleText
                switch iconStyle {
                case "battery": self.statusItem.button?.image = self.drawBatteryIcon(percent: end)
                case "circle": self.statusItem.button?.image = self.drawCircleIcon(percent: end)
                default: self.statusItem.button?.image = nil
                }
            }
            return
        }

        let showTitle = UserDefaults.standard.bool(forKey: "ShowScheduleTitle")
        let titlePrefix = titleText.replacingOccurrences(of: "\\s*\\d+%$", with: "", options: .regularExpression)
        
        var currentFrame = 0
        percentAnimationTimer = Timer.scheduledTimer(withTimeInterval: duration/Double(frameCount), repeats: true) { [weak self] t in
            guard let self = self, self.animationID == currentAnimationID else {
                t.invalidate()
                return
            }
            
            currentFrame += 1
            let progress = min(1.0, Double(currentFrame)/Double(frameCount))
            let value = Int(round(Double(start) + (Double(end-start) * progress)))
            self.displayPercent = value
            
            DispatchQueue.main.async {
                let prefixWithSpace = showTitle && !titlePrefix.isEmpty ? "\(titlePrefix) " : ""
                self.statusItem.button?.title = "\(prefixWithSpace)\(value)%"

                switch iconStyle {
                case "battery": self.statusItem.button?.image = self.drawBatteryIcon(percent: value)
                case "circle": self.statusItem.button?.image = self.drawCircleIcon(percent: value)
                default: self.statusItem.button?.image = nil
                }
            }
            
            if currentFrame >= frameCount {
                t.invalidate()
                self.displayPercent = end
                DispatchQueue.main.async { self.statusItem.button?.title = titleText }
            }
        }
    }
    
    func formatTimeLeft(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let lm = LocalizedManager.shared
        let format = lm.localized("time left format")
        return String(format: format, hours, minutes)
    }
    
    func drawBatteryIcon(percent: Int) -> NSImage? {
        let size = NSSize(width: 22, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(x: 1, y: 2, width: 18, height: 8)
        let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
        NSColor.gray.setStroke()
        path.lineWidth = 1.2
        path.stroke()
        let head = NSRect(x: 19, y: 4, width: 2, height: 4)
        let headPath = NSBezierPath(roundedRect: head, xRadius: 1, yRadius: 1)
        NSColor.gray.setFill()
        headPath.fill()
        let fillWidth = CGFloat(percent) * 16 / 100
        let fillRect = NSRect(x: 2, y: 3, width: fillWidth, height: 6)
        let fillColor = percent < 20 ? NSColor.systemRed : NSColor.systemGreen
        fillColor.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: 1, yRadius: 1).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    
    func drawCircleIcon(percent: Int) -> NSImage? {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        let center = CGPoint(x: 7, y: 7)
        let radius: CGFloat = 6
        let startAngle: CGFloat = 90
        let endAngle: CGFloat = 90 - 360 * CGFloat(percent) / 100
        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        NSColor.gray.withAlphaComponent(0.3).setStroke()
        bgPath.lineWidth = 2
        bgPath.stroke()
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
}

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
        hoverLayer.backgroundColor = NSColor.systemBlue.cgColor
        hoverLayer.opacity = 0
        hoverLayer.cornerRadius = 6
        hoverLayer.frame = bounds
        layer?.addSublayer(hoverLayer)
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
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.backgroundColor = .clear
        titleLabel.isBordered = false
        titleLabel.alignment = .left
        titleLabel.frame = NSRect(x: 28, y: 18, width: 120, height: 16)
        addSubview(titleLabel)
        timeLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.backgroundColor = .clear
        timeLabel.isBordered = false
        timeLabel.alignment = .left
        timeLabel.frame = NSRect(x: 28, y: 2, width: 120, height: 14)
        addSubview(timeLabel)
        percentLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        percentLabel.textColor = .systemBlue
        percentLabel.backgroundColor = .clear
        percentLabel.isBordered = false
        percentLabel.alignment = .right
        percentLabel.frame = NSRect(x: 160, y: 18, width: 40, height: 16)
        addSubview(percentLabel)
        bar.frame = NSRect(x: 160, y: 4, width: 40, height: 8)
        bar.minValue = 0; bar.maxValue = 1; bar.doubleValue = progress
        bar.isIndeterminate = false
        bar.controlSize = .small
        bar.style = .bar
        addSubview(bar)
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

