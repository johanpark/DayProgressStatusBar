import Cocoa

class SettingsWindowController: NSWindowController {
    let languageLabel = NSTextField(labelWithString: LocalizedManager.shared.localized("Language"))
    let languagePopup = NSPopUpButton()
    let showTitleCheckbox = NSButton(checkboxWithTitle: LocalizedManager.shared.localized("Show schedule title in status bar"), target: nil, action: nil)
    let saveButton = NSButton(title: LocalizedManager.shared.localized("Save"), target: nil, action: nil)
    let closeButton = NSButton(title: LocalizedManager.shared.localized("Close"), target: nil, action: nil)
    var onLanguageChanged: ((String) -> Void)?
    let languages = [
        ("ko", "한국어"),
        ("ja", "日本語"),
        ("zh", "中文"),
        ("en", "English"),
        ("de", "Deutsch")
    ]
    let iconStyleLabel = NSTextField(labelWithString: LocalizedManager.shared.localized("Progress Icon"))
    let iconStyleRadio = NSMatrix(frame: NSRect.zero, mode: .radioModeMatrix, prototype: NSButtonCell(), numberOfRows: 1, numberOfColumns: 3)
    let iconStyleOptions = [
        ("none", LocalizedManager.shared.localized("None")),
        ("battery", LocalizedManager.shared.localized("Battery")),
        ("circle", LocalizedManager.shared.localized("Circle"))
    ]
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = LocalizedManager.shared.localized("Settings")
        super.init(window: window)
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: Notification.Name("AppLanguageChanged"), object: nil)
        setupUI()
        updateLocalizedTexts()
    }
    required init?(coder: NSCoder) { fatalError() }
    func setupUI() {
        guard let content = window?.contentView else { return }
        languageLabel.frame = NSRect(x: 30, y: 140, width: 120, height: 24)
        languageLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        content.addSubview(languageLabel)
        languagePopup.frame = NSRect(x: 150, y: 140, width: 200, height: 26)
        languagePopup.removeAllItems()
        for lang in languages { languagePopup.addItem(withTitle: lang.1) }
        content.addSubview(languagePopup)
        
        iconStyleLabel.frame = NSRect(x: 30, y: 110, width: 120, height: 22)
        iconStyleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        content.addSubview(iconStyleLabel)
        
        iconStyleRadio.frame = NSRect(x: 150, y: 110, width: 200, height: 22)
        iconStyleRadio.cellClass = NSButtonCell.self
        iconStyleRadio.mode = .radioModeMatrix
        for (i, opt) in iconStyleOptions.enumerated() {
            let cell = NSButtonCell(textCell: opt.1)
            cell.setButtonType(.radio)
            iconStyleRadio.putCell(cell, atRow: 0, column: i)
        }
        let currentIconStyle = UserDefaults.standard.string(forKey: "StatusBarIconStyle") ?? "none"
        if let idx = iconStyleOptions.firstIndex(where: { $0.0 == currentIconStyle }) {
            iconStyleRadio.selectCell(atRow: 0, column: idx)
        }
        content.addSubview(iconStyleRadio)
        
        showTitleCheckbox.frame = NSRect(x: 30, y: 80, width: 320, height: 22)
        showTitleCheckbox.state = UserDefaults.standard.bool(forKey: "ShowScheduleTitle") ? .on : .off
        content.addSubview(showTitleCheckbox)
        
        let currentLangCode = UserDefaults.standard.string(forKey: "AppLanguage") ?? "ko"
        if let index = languages.firstIndex(where: { $0.0 == currentLangCode }) {
            languagePopup.selectItem(at: index)
        }
        
        saveButton.frame = NSRect(x: 100, y: 30, width: 90, height: 32)
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveTapped)
        content.addSubview(saveButton)
        closeButton.frame = NSRect(x: 210, y: 30, width: 90, height: 32)
        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        content.addSubview(closeButton)
    }
    @objc func saveTapped() {
        let idx = languagePopup.indexOfSelectedItem
        let langCode = languages[idx].0
        UserDefaults.standard.set(langCode, forKey: "AppLanguage")
        let showTitle = (showTitleCheckbox.state == .on)
        UserDefaults.standard.set(showTitle, forKey: "ShowScheduleTitle")
        let iconStyleIdx = iconStyleRadio.selectedColumn
        let iconStyle = iconStyleOptions[iconStyleIdx].0
        UserDefaults.standard.set(iconStyle, forKey: "StatusBarIconStyle")
        LocalizedManager.shared.updateBundle()
        NotificationCenter.default.post(name: Notification.Name("AppLanguageChanged"), object: langCode)
        NotificationCenter.default.post(name: Notification.Name("ShowScheduleTitleChanged"), object: showTitle)
        NotificationCenter.default.post(name: Notification.Name("StatusBarIconStyleChanged"), object: iconStyle)
        onLanguageChanged?(langCode)
        self.window?.close()
    }
    @objc func closeTapped() {
        self.window?.close()
    }
    @objc func languageChanged() {
        updateLocalizedTexts()
    }
    func updateLocalizedTexts() {
        window?.title = LocalizedManager.shared.localized("Settings")
        languageLabel.stringValue = LocalizedManager.shared.localized("Language")
        showTitleCheckbox.title = LocalizedManager.shared.localized("Show schedule title in status bar")
        iconStyleLabel.stringValue = LocalizedManager.shared.localized("Progress Icon")
        for (i, opt) in iconStyleOptions.enumerated() {
            iconStyleRadio.cell(atRow: 0, column: i)?.title = opt.1
        }
        saveButton.title = LocalizedManager.shared.localized("Save")
        closeButton.title = LocalizedManager.shared.localized("Close")
    }
}
