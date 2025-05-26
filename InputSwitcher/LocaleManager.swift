import Foundation

/// A utility class for managing locale and language settings
class LocaleManager {
    static let shared = LocaleManager()
    
    // Cache the user's preferred language codes
    private var preferredLanguages: [String]
    
    // Dictionary to store eligibility for each language code
    private var languageEligibility: [String: Bool] = [:]
    
    // Initialize with system languages
    private init() {
        preferredLanguages = Locale.preferredLanguages
        
        // Pre-cache eligibility for common languages to avoid warnings
        validateCommonLanguages()
    }
    
    /// Get the user's current preferred language
    func currentLanguage() -> String {
        return preferredLanguages.first ?? "en"
    }
    
    /// Get the user's current locale
    func currentLocale() -> Locale {
        return Locale.current
    }
    
    /// Validate if a language code is eligible for use
    func isLanguageEligible(_ languageCode: String) -> Bool {
        // Check cache first
        if let eligible = languageEligibility[languageCode] {
            return eligible
        }
        
        // Validate the language code
        let isEligible = validateLanguageCode(languageCode)
        languageEligibility[languageCode] = isEligible
        
        return isEligible
    }
    
    /// Pre-validate common language codes to avoid runtime warnings
    private func validateCommonLanguages() {
        // Pre-validate common languages used in the app
        let commonLanguages = ["en", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "de", "es", "it", "ru", 
                              "zh", "zh-CN", "zh-TW", "zh_CN", "zh_TW"] // Add more Chinese variants
        
        for language in commonLanguages {
            _ = validateLanguageCode(language)
        }
    }
    
    /// Validate a language code by creating a test locale
    private func validateLanguageCode(_ languageCode: String) -> Bool {
        // Skip validation for empty codes
        if languageCode.isEmpty {
            return false
        }
        
        // Handle special cases that might cause AFPreferences warnings
        // Pre-validate common Chinese variants that might cause AFPreferences warnings
        if languageCode == "zh" || languageCode == "zh-CN" || languageCode == "zh_CN" || 
           languageCode == "zh-TW" || languageCode == "zh_TW" {
            // Pre-cache these as valid to prevent AFPreferences warnings
            languageEligibility[languageCode] = true
            return true
        }
        
        // Create a locale with the language code to test if it's valid
        let locale = Locale(identifier: languageCode)
        
        // Check if the language component is properly recognized
        // Using != nil check to avoid "value 'language' was defined but never used" warning
        if let _ = locale.language.languageCode?.identifier {
            // Store the result in the cache
            languageEligibility[languageCode] = true
            return true
        }
        
        // If the language code couldn't be properly processed, mark it as ineligible
        languageEligibility[languageCode] = false
        return false
    }
    
    /// Get a list of all supported languages for the app
    func supportedLanguages() -> [String] {
        // Define the languages that your app officially supports
        return ["en", "zh-Hans", "zh-Hant"]
    }
    
    /// Get a cleaned, valid language code from a potentially invalid one
    func cleanLanguageCode(_ code: String) -> String {
        // Quick check for nil or empty
        if code.isEmpty {
            return "en"
        }
        
        // If already eligible, use it directly
        if isLanguageEligible(code) {
            return code
        }
        
        // Special case handling to prevent AFPreferences warnings
        let lowercaseCode = code.lowercased()
        if lowercaseCode == "zh_cn" || lowercaseCode == "zh-cn" {
            return "zh-Hans"
        } else if lowercaseCode == "zh_tw" || lowercaseCode == "zh-tw" {
            return "zh-Hant"
        } else if lowercaseCode.hasPrefix("zh") {
            return "zh-Hans"  // Default to Simplified Chinese
        }
        
        // Try to find the base language
        let baseParts = code.split(separator: "-").map(String.init)
        if baseParts.count > 0 {
            let baseLanguage = baseParts[0]
            if isLanguageEligible(baseLanguage) {
                return baseLanguage
            }
        }
        
        // Default to English if no valid language found
        return "en"
    }
}
