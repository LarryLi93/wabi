import Foundation
import Combine
import SwiftUI

class LocalizationManager: ObservableObject {
    @Published var currentLanguage: String = "en" {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "selectedLanguage")
            loadStrings()
        }
    }

    private var localizedStrings: [String: String] = [:]

    init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") {
            currentLanguage = savedLanguage
        } else if Locale.preferredLanguages.first?.hasPrefix("zh") == true {
            currentLanguage = "zh"
        }
        loadStrings()
    }

    var locale: Locale {
        Locale(identifier: currentLanguage == "zh" ? "zh-Hans" : "en")
    }

    private func loadStrings() {
        let resourceName = currentLanguage == "zh" ? "Localizable-zh" : "Localizable"

        guard let path = Bundle.main.path(forResource: resourceName, ofType: "strings"),
              let dictionary = NSDictionary(contentsOfFile: path) as? [String: String] else {
            localizedStrings = [:]
            return
        }

        localizedStrings = dictionary
    }

    func localizedString(for key: String) -> String {
        localizedStrings[key] ?? key
    }

    func setLanguage(_ language: String) {
        guard currentLanguage != language else {
            return
        }

        currentLanguage = language
    }

    func toggleLanguage() {
        currentLanguage = currentLanguage == "en" ? "zh" : "en"
    }
}

extension String {
    func localized(with manager: LocalizationManager? = nil) -> String {
        if let manager {
            return manager.localizedString(for: self)
        }

        return self
    }
}
