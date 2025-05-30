//
//  ScheduleEditWindowController.swift
//  DayProgressStatusBar
//
//  Created by john on 5/29/25.
//

import Cocoa

class ScheduleEditWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    
    // MARK: - UI 컴포넌트
    let titleField = NSTextField(string: "")
    let startPicker = NSDatePicker()
    let endPicker = NSDatePicker()
    let colorWell = NSColorWell()
    let saveButton = NSButton()
    let cancelButton = NSButton()
    
    let tableView = NSTableView()
    let scrollView = NSScrollView()
    var schedules: [Schedule] = ScheduleStorage.shared.load()
    
    var editingIndex: Int?
    var existingSchedule: Schedule?
    
    init(schedule: Schedule?, index: Int? = nil) {
        self.existingSchedule = schedule
        self.editingIndex = index

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "일정 관리"

        super.init(window: window)

        setupUI()
        applySchedule()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI 구성
    func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Only add the scrollView (tableView) and new management buttons
        scrollView.frame = NSRect(x: 20, y: 80, width: 320, height: 380)
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        contentView.addSubview(scrollView)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ScheduleColumn"))
        column.title = "일정 제목"
        column.width = 320
        if tableView.tableColumns.isEmpty {
            tableView.addTableColumn(column)
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil

        // Add management buttons
        let addButton = NSButton(title: "추가", target: self, action: #selector(addTapped))
        let editButton = NSButton(title: "수정", target: self, action: #selector(editTapped))
        let deleteButton = NSButton(title: "삭제", target: self, action: #selector(deleteTapped))

        addButton.frame = NSRect(x: 20, y: 20, width: 80, height: 28)
        editButton.frame = NSRect(x: 110, y: 20, width: 80, height: 28)
        deleteButton.frame = NSRect(x: 200, y: 20, width: 80, height: 28)

        contentView.addSubview(addButton)
        contentView.addSubview(editButton)
        contentView.addSubview(deleteButton)
    }
    
    // MARK: - 기존 데이터 세팅
    func applySchedule() {
        // No-op in management mode
    }
    
    // MARK: - 액션
    @objc func saveTapped() {
        // Not used in management mode
    }

    @objc func cancelTapped() {
        // Not used in management mode
    }

    // Retain controller to keep sheet alive during presentation
    var addEditSheetController: ScheduleEditFormWindowController?

    @objc func addTapped() {
        let controller = ScheduleEditFormWindowController()
        self.addEditSheetController = controller

        guard let sheetWindow = controller.window else {
            print("🚨 ScheduleEditFormWindowController의 window가 nil입니다.")
            return
        }

        self.window?.beginSheet(sheetWindow) { [weak self] _ in
            self?.addEditSheetController = nil
        }
    }

    @objc func editTapped() {
        let selected = tableView.selectedRow
        guard selected >= 0 else { return }
        let schedule = schedules[selected]
        let controller = ScheduleEditFormWindowController(schedule: schedule, index: selected)
        self.addEditSheetController = controller

        guard let sheetWindow = controller.window else {
            print("🚨 ScheduleEditFormWindowController의 window가 nil입니다.")
            return
        }

        self.window?.beginSheet(sheetWindow) { [weak self] _ in
            self?.addEditSheetController = nil
        }
    }

    @objc func deleteTapped() {
        let selected = tableView.selectedRow
        guard selected >= 0 else { return }
        schedules.remove(at: selected)
        ScheduleStorage.shared.save(schedules)
        tableView.reloadData()
    }
    
    func hasConflictSchedule(start: DateComponents, end: DateComponents, ignoreIndex: Int? = nil) -> Bool {
        let schedules = ScheduleStorage.shared.load()
        let calendar = Calendar.current

        for (index, schedule) in schedules.enumerated() {
            if let ignore = ignoreIndex, index == ignore { continue }

            guard let s1 = calendar.date(from: schedule.start),
                  let e1 = calendar.date(from: schedule.end),
                  let s2 = calendar.date(from: start),
                  let e2 = calendar.date(from: end) else { continue }

            if s1 < e2 && s2 < e1 {
                return true
            }
        }
        return false
    }
    
    // MARK: - NSTableViewDataSource & Delegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        return schedules.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let schedule = schedules[row]
        let cell = NSTextField(labelWithString: schedule.title)
        cell.font = NSFont.systemFont(ofSize: 13)
        return cell
    }

    // MARK: - Notification for saving (for modal windows)
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        tableView.reloadData()
    }

    // Listen for .scheduleSaved to update local schedules and reload table view
    override func windowDidLoad() {
        super.windowDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(handleScheduleSaved(_:)), name: .scheduleSaved, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleScheduleListUpdated), name: .scheduleListUpdated, object: nil)
    }

    @objc func handleScheduleSaved(_ notification: Notification) {
        guard let (schedule, index) = notification.object as? (Schedule, Int?) else { return }

        // 저장된 데이터 새로 불러오기
        let updatedSchedules = ScheduleStorage.shared.load()

        // 스케줄이 이미 존재하는 경우 교체
        if let i = index {
            if i < updatedSchedules.count {
                schedules[i] = updatedSchedules[i]
            }
        } else {
            // 새로 추가된 스케줄을 찾아서 추가
            let newIDs = Set(updatedSchedules.map { $0.id }).subtracting(schedules.map { $0.id })
            if let newSchedule = updatedSchedules.first(where: { newIDs.contains($0.id) }) {
                schedules.append(newSchedule)
            }
        }

        tableView.reloadData()
    }

    @objc func handleScheduleListUpdated() {
        schedules = ScheduleStorage.shared.load()
        tableView.reloadData()
    }
}

class ScheduleEditFormWindowController: NSWindowController {
    let titleField = NSTextField()
    let startPicker = NSDatePicker()
    let endPicker = NSDatePicker()
    let colorWell = NSColorWell()
    let saveButton = NSButton()
    let cancelButton = NSButton()

    var editingSchedule: Schedule?
    var editingIndex: Int?

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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        guard let content = window?.contentView else { return }

        titleField.frame = NSRect(x: 20, y: 160, width: 260, height: 24)
        startPicker.frame = NSRect(x: 20, y: 120, width: 260, height: 24)
        endPicker.frame = NSRect(x: 20, y: 90, width: 260, height: 24)
        colorWell.frame = NSRect(x: 20, y: 60, width: 50, height: 24)

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

        NotificationCenter.default.post(name: .scheduleSaved, object: (newSchedule, editingIndex))
        NotificationCenter.default.post(name: .scheduleListUpdated, object: nil)
        self.window?.sheetParent?.endSheet(self.window!)
    }

    @objc func cancelTapped() {
        self.window?.sheetParent?.endSheet(self.window!)
    }
}
