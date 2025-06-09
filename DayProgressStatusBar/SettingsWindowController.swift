import Cocoa

class SettingsWindowController: NSWindowController {
    // MARK: - UI Elements
    let languageLabel = NSTextField(labelWithString: "")
    let languagePopup = NSPopUpButton()
    let iconStyleLabel = NSTextField(labelWithString: "")
    let iconStylePopup = NSPopUpButton()
    let showTitleCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let showTimeLeftCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let saveButton = NSButton(title: "", target: nil, action: nil)
    let closeButton = NSButton(title: "", target: nil, action: nil)
    var onLanguageChanged: ((String) -> Void)?
    // MARK: - Data
    let languages = [
        ("ko", "한국어"), ("ja", "日本語"), ("zh", "中文"), ("en", "English"), ("de", "Deutsch")
    ]
    let iconStyleOptions = [
        ("none", "None"), ("battery", "Battery"), ("circle", "Circle")
    ]
    // MARK: - Layout Constants
    let leftLabelX: CGFloat = 30
    let rightInputX: CGFloat = 150
    let fieldWidth: CGFloat = 200
    let fieldHeight: CGFloat = 26
    let checkboxWidth: CGFloat = 320
    let checkboxHeight: CGFloat = 22
    let buttonWidth: CGFloat = 90
    let buttonHeight: CGFloat = 32
    let verticalSpacing: CGFloat = 40
    let windowWidth: CGFloat = 380
    let windowHeight: CGFloat = 240
    // MARK: - Init
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
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
    // MARK: - UI Setup
    func setupUI() {
        guard let content = window?.contentView else { return }
        content.subviews.forEach { $0.removeFromSuperview() }
        // 배경: 다크/라이트 모드 자동 대응
        let blur = NSVisualEffectView(frame: content.bounds)
        blur.autoresizingMask = [.width, .height]
        blur.blendingMode = .behindWindow
        blur.material = .sidebar
        blur.state = .active
        content.addSubview(blur, positioned: .below, relativeTo: nil)
        // 언어
        configureLabel(languageLabel, y: 200)
        languageLabel.textColor = NSColor.labelColor
        configurePopup(languagePopup, y: 200, items: languages.map { $0.1 }, selected: getCurrentLanguageIndex())
        // 아이콘 스타일
        configureLabel(iconStyleLabel, y: 160)
        iconStyleLabel.textColor = NSColor.labelColor
        configurePopup(iconStylePopup, y: 160, items: iconStyleOptions.map { LocalizedManager.shared.localized($0.1) }, selected: getCurrentIconStyleIndex())
        // 체크박스
        configureCheckbox(showTitleCheckbox, y: 120, value: UserDefaults.standard.bool(forKey: "ShowScheduleTitle"))
        configureCheckbox(showTimeLeftCheckbox, y: 90, value: UserDefaults.standard.bool(forKey: "ShowTimeLeftInsteadOfPercent"))
        // 버튼
        configureButton(saveButton, x: 100, y: 30, width: buttonWidth, title: LocalizedManager.shared.localized("Save"), action: #selector(saveTapped))
        saveButton.contentTintColor = NSColor.controlAccentColor
        configureButton(closeButton, x: 210, y: 30, width: buttonWidth, title: LocalizedManager.shared.localized("Close"), action: #selector(closeTapped))
        closeButton.contentTintColor = NSColor.labelColor
        // addSubview
        [languageLabel, languagePopup, iconStyleLabel, iconStylePopup, showTitleCheckbox, showTimeLeftCheckbox, saveButton, closeButton].forEach { content.addSubview($0) }
    }
    // MARK: - UI Helpers
    func configureLabel(_ label: NSTextField, y: CGFloat) {
        label.frame = NSRect(x: leftLabelX, y: y, width: fieldWidth, height: 24)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
    }
    func configurePopup(_ popup: NSPopUpButton, y: CGFloat, items: [String], selected: Int) {
        popup.frame = NSRect(x: rightInputX, y: y, width: fieldWidth, height: fieldHeight)
        popup.removeAllItems()
        items.forEach { popup.addItem(withTitle: $0) }
        if selected >= 0 { popup.selectItem(at: selected) }
    }
    func configureCheckbox(_ checkbox: NSButton, y: CGFloat, value: Bool) {
        checkbox.frame = NSRect(x: leftLabelX, y: y, width: checkboxWidth, height: checkboxHeight)
        checkbox.state = value ? .on : .off
    }
    func configureButton(_ button: NSButton, x: CGFloat, y: CGFloat, width: CGFloat, title: String, action: Selector) {
        button.frame = NSRect(x: x, y: y, width: width, height: buttonHeight)
        button.bezelStyle = .rounded
        button.title = title
        button.target = self
        button.action = action
    }
    // MARK: - Data Helpers
    func getCurrentLanguageIndex() -> Int {
        let currentLangCode = UserDefaults.standard.string(forKey: "AppLanguage") ?? "ko"
        return languages.firstIndex(where: { $0.0 == currentLangCode }) ?? 0
    }
    func getCurrentIconStyleIndex() -> Int {
        let currentIconStyle = UserDefaults.standard.string(forKey: "StatusBarIconStyle") ?? "none"
        return iconStyleOptions.firstIndex(where: { $0.0 == currentIconStyle }) ?? 0
    }
    // MARK: - Actions
    @objc func saveTapped() {
        let langIdx = languagePopup.indexOfSelectedItem
        let langCode = languages[langIdx].0
        UserDefaults.standard.set(langCode, forKey: "AppLanguage")
        let showTitle = (showTitleCheckbox.state == .on)
        UserDefaults.standard.set(showTitle, forKey: "ShowScheduleTitle")
        let iconStyleIdx = iconStylePopup.indexOfSelectedItem
        let iconStyle = iconStyleOptions[iconStyleIdx].0
        UserDefaults.standard.set(iconStyle, forKey: "StatusBarIconStyle")
        let showTimeLeft = (showTimeLeftCheckbox.state == .on)
        UserDefaults.standard.set(showTimeLeft, forKey: "ShowTimeLeftInsteadOfPercent")
        LocalizedManager.shared.updateBundle()
        NotificationCenter.default.post(name: Notification.Name("AppLanguageChanged"), object: langCode)
        NotificationCenter.default.post(name: Notification.Name("ShowScheduleTitleChanged"), object: showTitle)
        NotificationCenter.default.post(name: Notification.Name("StatusBarIconStyleChanged"), object: iconStyle)
        NotificationCenter.default.post(name: Notification.Name("ShowTimeLeftInsteadOfPercentChanged"), object: showTimeLeft)
        onLanguageChanged?(langCode)
        self.window?.close()
    }
    @objc func closeTapped() {
        self.window?.close()
    }
    @objc func languageChanged() {
        updateLocalizedTexts()
    }
    // MARK: - Localized Texts
    func updateLocalizedTexts() {
        window?.title = LocalizedManager.shared.localized("Settings")
        languageLabel.stringValue = LocalizedManager.shared.localized("Language")
        iconStyleLabel.stringValue = LocalizedManager.shared.localized("Progress Icon")
        showTitleCheckbox.title = LocalizedManager.shared.localized("Show schedule title in status bar")
        showTimeLeftCheckbox.title = LocalizedManager.shared.localized("Show time left instead of percent")
        saveButton.title = LocalizedManager.shared.localized("Save")
        closeButton.title = LocalizedManager.shared.localized("Close")
        // 아이콘 스타일 옵션 다국어 반영
        configurePopup(iconStylePopup, y: iconStylePopup.frame.origin.y, items: iconStyleOptions.map { LocalizedManager.shared.localized($0.1) }, selected: getCurrentIconStyleIndex())
    }
}
