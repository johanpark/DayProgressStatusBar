//
//  ScheduleEditWindowController.swift
//  DayProgressStatusBar
//
//  Created by john on 5/29/25.
//

import Cocoa

class ScheduleEditWindowController: NSWindowController {

    // MARK: - UI 컴포넌트
    let titleField = NSTextField(string: "")
    let startPicker = NSDatePicker()
    let endPicker = NSDatePicker()
    let colorWell = NSColorWell()
    let saveButton = NSButton()
    let cancelButton = NSButton()

    var editingIndex: Int?
    var existingSchedule: Schedule?

    init(schedule: Schedule?, index: Int? = nil) {
        self.existingSchedule = schedule
        self.editingIndex = index

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = index == nil ? "일정 추가" : "일정 수정"

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

        let labelFont = NSFont.systemFont(ofSize: 13)
        let titleLabel = NSTextField(labelWithString: "제목")
        let startLabel = NSTextField(labelWithString: "시작")
        let endLabel = NSTextField(labelWithString: "종료")
        let colorLabel = NSTextField(labelWithString: "색상")

        [titleLabel, startLabel, endLabel, colorLabel].forEach {
            $0.font = labelFont
        }

        // 위치 및 크기 설정
        titleLabel.frame = NSRect(x: 20, y: 180, width: 40, height: 24)
        titleField.frame = NSRect(x: 70, y: 180, width: 200, height: 24)

        startLabel.frame = NSRect(x: 20, y: 140, width: 40, height: 24)
        startPicker.frame = NSRect(x: 70, y: 140, width: 200, height: 24)

        endLabel.frame = NSRect(x: 20, y: 100, width: 40, height: 24)
        endPicker.frame = NSRect(x: 70, y: 100, width: 200, height: 24)

        colorLabel.frame = NSRect(x: 20, y: 60, width: 40, height: 24)
        colorWell.frame = NSRect(x: 70, y: 60, width: 100, height: 24)

        saveButton.frame = NSRect(x: 70, y: 20, width: 80, height: 28)
        saveButton.title = "저장"
        saveButton.target = self
        saveButton.action = #selector(saveTapped)
        cancelButton.frame = NSRect(x: 160, y: 20, width: 80, height: 28)
        cancelButton.title = "취소"
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        
        
        startPicker.datePickerStyle = .textFieldAndStepper
        startPicker.datePickerElements = [.hourMinute]
        endPicker.datePickerStyle = .textFieldAndStepper
        endPicker.datePickerElements = [.hourMinute]


        contentView.addSubview(titleLabel)
        contentView.addSubview(titleField)
        contentView.addSubview(startLabel)
        contentView.addSubview(startPicker)
        contentView.addSubview(endLabel)
        contentView.addSubview(endPicker)
        contentView.addSubview(colorLabel)
        contentView.addSubview(colorWell)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)
        contentView.nextResponder = self
    }

    // MARK: - 기존 데이터 세팅
    func applySchedule() {
        if let schedule = existingSchedule {
            titleField.stringValue = schedule.title
            startPicker.dateValue = Calendar.current.date(from: schedule.start) ?? Date()
            endPicker.dateValue = Calendar.current.date(from: schedule.end) ?? Date()
            colorWell.color = NSColor(hex: schedule.colorHex) ?? .systemBlue
        } else {
            titleField.stringValue = ""
            startPicker.dateValue = Date()
            endPicker.dateValue = Date()
            colorWell.color = .systemBlue
        }
    }

    // MARK: - 액션
    @objc func saveTapped() {
        let title = titleField.stringValue
        let startComp = Calendar.current.dateComponents([.hour, .minute], from: startPicker.dateValue)
        let endComp = Calendar.current.dateComponents([.hour, .minute], from: endPicker.dateValue)

        if hasConflictSchedule(start: startComp, end: endComp, ignoreIndex: editingIndex) {
            let alert = NSAlert()
            alert.messageText = "중복된 일정이 있습니다."
            alert.informativeText = "겹치지 않도록 시간을 조정해주세요."
            alert.runModal()
            return
        }

        let hex = colorWell.color.hexString
        let newSchedule = Schedule(id: UUID(), title: title, start: startComp, end: endComp, colorHex: hex)

        NotificationCenter.default.post(name: .scheduleSaved, object: (newSchedule, editingIndex))
        self.close()
    }

    @objc func cancelTapped() {
        self.close()
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
}
