import Cocoa

class ScheduleManagerWindowController: NSWindowController {
    let titleLabel = NSTextField(labelWithString: LocalizedManager.shared.localized("Manage Schedules"))
    let closeButton = NSButton()
    let scrollView = NSScrollView()
    let stackView = NSStackView()
    let addButton = NSButton()
    var schedules: [Schedule] = []
    var addEditSheetController: ScheduleManagerAddEditSheetController?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = LocalizedManager.shared.localized("Manage Schedules")
        window.level = .normal
        super.init(window: window)
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: Notification.Name("AppLanguageChanged"), object: nil)
        setupUI()
        reloadSchedules()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setupUI() {
        guard let contentView = window?.contentView else { return }
        // 타이틀
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 0, y: 480, width: 380, height: 32)
        contentView.addSubview(titleLabel)
        // 닫기 버튼
        closeButton.title = LocalizedManager.shared.localized("Close")
        closeButton.frame = NSRect(x: 320, y: 485, width: 50, height: 24)
        closeButton.bezelStyle = .rounded
        closeButton.setButtonType(.momentaryPushIn)
        closeButton.isBordered = true
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        contentView.addSubview(closeButton)
        // 리스트 스크롤뷰
        scrollView.frame = NSRect(x: 20, y: 70, width: 340, height: 390)
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        contentView.addSubview(scrollView)
        // StackView(일정 리스트)
        stackView.orientation = .vertical
        stackView.spacing = 10
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stackView
        // 추가 버튼
        addButton.title = "+ " + LocalizedManager.shared.localized("Add Schedule")
        addButton.frame = NSRect(x: 110, y: 20, width: 160, height: 36)
        addButton.bezelStyle = .rounded
        addButton.setButtonType(.momentaryPushIn)
        addButton.isBordered = true
        addButton.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        addButton.target = self
        addButton.action = #selector(addTapped)
        contentView.addSubview(addButton)
        // 디버깅용 프린트
        print("closeButton: superview=\(closeButton.superview != nil), window=\(closeButton.window != nil), nextResponder=\(closeButton.nextResponder)")
        print("addButton: superview=\(addButton.superview != nil), window=\(addButton.window != nil), nextResponder=\(addButton.nextResponder)")
    }

    func reloadSchedules() {
        schedules = ScheduleStorage.shared.load()
        print("불러온 일정 개수: \(schedules.count)")
        for sub in stackView.arrangedSubviews { stackView.removeArrangedSubview(sub); sub.removeFromSuperview() }
        if schedules.isEmpty {
            let label = NSTextField(labelWithString: LocalizedManager.shared.localized("No schedules registered."))
            label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            label.frame = NSRect(x: 0, y: 0, width: 320, height: 40)
            stackView.addArrangedSubview(label)
            stackView.frame = NSRect(x: 0, y: 0, width: scrollView.contentSize.width, height: 50)
            stackView.distribution = .fill
            return
        }
        for (idx, schedule) in schedules.enumerated() {
            print("일정 \(idx): \(schedule.title)")
            let card = ScheduleManagerCardView(schedule: schedule, index: idx, target: self)
            card.frame = NSRect(x: 0, y: 0, width: 320, height: 56)
            stackView.addArrangedSubview(card)
        }
        let height = CGFloat(schedules.count) * 60
        stackView.frame = NSRect(x: 0, y: 0, width: scrollView.contentSize.width, height: max(390, height))
        stackView.distribution = .fill
    }

    @objc func addTapped() {
        if addEditSheetController != nil { return }
        let controller = ScheduleManagerAddEditSheetController()
        controller.completion = { [weak self] in self?.reloadSchedules() }
        self.addEditSheetController = controller
        guard let sheetWindow = controller.window else { return }
        self.window?.beginSheet(sheetWindow) { [weak self] _ in self?.addEditSheetController = nil }
    }
    @objc func editTapped(_ sender: NSButton) {
        let idx = sender.tag
        let schedule = schedules[idx]
        let controller = ScheduleManagerAddEditSheetController(schedule: schedule, index: idx)
        controller.completion = { [weak self] in self?.reloadSchedules() }
        self.addEditSheetController = controller
        guard let sheetWindow = controller.window else { return }
        self.window?.beginSheet(sheetWindow) { [weak self] _ in self?.addEditSheetController = nil }
    }
    @objc func deleteTapped(_ sender: NSButton) {
        let idx = sender.tag
        schedules.remove(at: idx)
        ScheduleStorage.shared.save(schedules)
        reloadSchedules()
    }
    @objc func repTapped(_ sender: NSButton) {
        let idx = sender.tag
        for i in 0..<schedules.count { schedules[i].isRepresentative = false }
        schedules[idx].isRepresentative = true
        ScheduleStorage.shared.save(schedules)
        reloadSchedules()
    }
    @objc func closeWindow() {
        if let window = self.window, let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            self.window?.close()
        }
    }
    @objc func languageChanged() {
        LocalizedManager.shared.updateBundle()
        window?.title = LocalizedManager.shared.localized("Manage Schedules")
        titleLabel.stringValue = LocalizedManager.shared.localized("Manage Schedules")
        closeButton.title = LocalizedManager.shared.localized("Close")
        addButton.title = "+ " + LocalizedManager.shared.localized("Add Schedule")
        reloadSchedules()
    }
}

// 일정 카드(행) 뷰
class ScheduleManagerCardView: NSView {
    init(schedule: Schedule, index: Int, target: ScheduleManagerWindowController) {
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 56))
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
        layer?.cornerRadius = 10
        // 대표
        let repBtn = NSButton()
        repBtn.bezelStyle = .inline
        repBtn.isBordered = false
        repBtn.title = ""
        repBtn.image = NSImage(systemSymbolName: schedule.isRepresentative ? "star.fill" : "star", accessibilityDescription: nil)
        repBtn.imagePosition = .imageOnly
        repBtn.frame = NSRect(x: 10, y: 18, width: 20, height: 20)
        repBtn.target = target
        repBtn.action = #selector(target.repTapped(_:))
        repBtn.tag = index
        addSubview(repBtn)
        // 일정명
        let title = NSTextField(labelWithString: schedule.title)
        title.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .labelColor
        title.backgroundColor = .clear
        title.isBordered = false
        title.alignment = .left
        title.frame = NSRect(x: 40, y: 28, width: 120, height: 20)
        addSubview(title)
        // 시간
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        var startComp = schedule.start
        var endComp = schedule.end
        startComp.year = today.year; startComp.month = today.month; startComp.day = today.day
        endComp.year = today.year; endComp.month = today.month; endComp.day = today.day
        let start = calendar.date(from: startComp) ?? now
        let end = calendar.date(from: endComp) ?? now
        let time = NSTextField(labelWithString: String(format: "%@ ~ %@", AppDelegate.formatTimeStatic(start), AppDelegate.formatTimeStatic(end)))
        time.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        time.textColor = .secondaryLabelColor
        time.backgroundColor = .clear
        time.isBordered = false
        time.alignment = .left
        time.frame = NSRect(x: 40, y: 10, width: 120, height: 16)
        addSubview(time)
        // 색상
        let colorWell = NSColorWell(frame: NSRect(x: 170, y: 18, width: 28, height: 20))
        colorWell.color = NSColor(hex: schedule.colorHex) ?? .systemBlue
        colorWell.isEnabled = false
        addSubview(colorWell)
        // 수정 버튼
        let editBtn = NSButton(title: LocalizedManager.shared.localized("Edit"), target: target, action: #selector(target.editTapped(_:)))
        editBtn.bezelStyle = .rounded
        editBtn.font = NSFont.systemFont(ofSize: 13)
        editBtn.frame = NSRect(x: 210, y: 18, width: 50, height: 24)
        editBtn.tag = index
        addSubview(editBtn)
        // 삭제 버튼
        let delBtn = NSButton(title: LocalizedManager.shared.localized("Delete"), target: target, action: #selector(target.deleteTapped(_:)))
        delBtn.bezelStyle = .rounded
        delBtn.font = NSFont.systemFont(ofSize: 13)
        delBtn.frame = NSRect(x: 265, y: 18, width: 50, height: 24)
        delBtn.tag = index
        addSubview(delBtn)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 320, height: 56)
    }
}

// 일정 추가/수정 시트
class ScheduleManagerAddEditSheetController: NSWindowController {
    let titleField = NSTextField()
    let startPicker = NSDatePicker()
    let endPicker = NSDatePicker()
    let colorWell = NSColorWell()
    let saveButton = NSButton()
    let cancelButton = NSButton()
    var editingSchedule: Schedule?
    var editingIndex: Int?
    var completion: (() -> Void)?
    init(schedule: Schedule? = nil, index: Int? = nil) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = schedule == nil ? "일정 추가" : "일정 수정"
        super.init(window: window)
        self.editingSchedule = schedule
        self.editingIndex = index
        setupUI()
        applySchedule()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func setupUI() {
        guard let content = window?.contentView else { return }
        titleField.frame = NSRect(x: 20, y: 160, width: 260, height: 24)
        startPicker.frame = NSRect(x: 20, y: 120, width: 260, height: 24)
        endPicker.frame = NSRect(x: 20, y: 90, width: 260, height: 24)
        colorWell.frame = NSRect(x: 20, y: 60, width: 50, height: 24)
        startPicker.datePickerElements = .hourMinute
        endPicker.datePickerElements = .hourMinute
        startPicker.datePickerStyle = .textFieldAndStepper
        endPicker.datePickerStyle = .textFieldAndStepper
        startPicker.datePickerMode = .single
        endPicker.datePickerMode = .single
        saveButton.title = "저장"
        saveButton.frame = NSRect(x: 170, y: 20, width: 50, height: 30)
        saveButton.target = self
        saveButton.action = #selector(saveTapped)
        cancelButton.title = "취소"
        cancelButton.frame = NSRect(x: 230, y: 20, width: 50, height: 30)
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        [titleField, startPicker, endPicker, colorWell, saveButton, cancelButton].forEach { content.addSubview($0) }
    }
    func applySchedule() {
        guard let schedule = editingSchedule else { return }
        titleField.stringValue = schedule.title
        startPicker.dateValue = Calendar.current.date(from: schedule.start) ?? Date()
        endPicker.dateValue = Calendar.current.date(from: schedule.end) ?? Date()
        colorWell.color = NSColor(hex: schedule.colorHex) ?? .systemBlue
    }
    @objc func saveTapped() {
        let calendar = Calendar.current
        let newSchedule = Schedule(
            id: editingSchedule?.id ?? UUID(),
            title: titleField.stringValue,
            start: calendar.dateComponents([.hour, .minute], from: startPicker.dateValue),
            end: calendar.dateComponents([.hour, .minute], from: endPicker.dateValue),
            colorHex: colorWell.color.hexString,
            isRepresentative: editingSchedule?.isRepresentative ?? false
        )
        var schedules = ScheduleStorage.shared.load()
        if let idx = editingIndex {
            schedules[idx] = newSchedule
        } else {
            schedules.append(newSchedule)
        }
        ScheduleStorage.shared.save(schedules)
        NotificationCenter.default.post(name: .scheduleListUpdated, object: nil)
        if let window = self.window, let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            self.window?.close()
        }
        completion?()
    }
    @objc func cancelTapped() {
        if let window = self.window, let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            self.window?.close()
        }
    }
} 