import Cocoa

class SettingsWindowController: NSWindowController {
    let languageLabel = NSTextField(labelWithString: LocalizedManager.shared.localized("Language"))
    let languagePopup = NSPopUpButton()
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
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 140),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = LocalizedManager.shared.localized("Settings")
        super.init(window: window)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }
    func setupUI() {
        guard let content = window?.contentView else { return }
        languageLabel.frame = NSRect(x: 30, y: 80, width: 80, height: 24)
        languageLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        content.addSubview(languageLabel)
        languagePopup.frame = NSRect(x: 120, y: 80, width: 150, height: 26)
        for lang in languages { languagePopup.addItem(withTitle: lang.1) }
        content.addSubview(languagePopup)
        saveButton.frame = NSRect(x: 80, y: 30, width: 80, height: 32)
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveTapped)
        saveButton.sizeToFit()
        content.addSubview(saveButton)
        closeButton.frame = NSRect(x: 180, y: 30, width: 80, height: 32)
        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.sizeToFit()
        content.addSubview(closeButton)
    }
    @objc func saveTapped() {
        let idx = languagePopup.indexOfSelectedItem
        let langCode = languages[idx].0
        UserDefaults.standard.set(langCode, forKey: "AppLanguage")
        LocalizedManager.shared.updateBundle()
        NotificationCenter.default.post(name: Notification.Name("AppLanguageChanged"), object: langCode)
        onLanguageChanged?(langCode)
        self.window?.close()
    }
    @objc func closeTapped() {
        self.window?.close()
    }
} 