import Foundation

class LocalizedManager {
    static let shared = LocalizedManager()
    private var bundle: Bundle = .main

    private init() {
        updateBundle()
    }

    func updateBundle() {
        let lang = UserDefaults.standard.string(forKey: "AppLanguage") ?? Locale.preferredLanguages.first ?? "en"
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else {
            bundle = .main
        }
    }

    func localized(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    var languageCode: String {
        let lang = UserDefaults.standard.string(forKey: "AppLanguage") ?? Locale.preferredLanguages.first ?? "en"
        return String(lang.prefix(2))
    }
} 
