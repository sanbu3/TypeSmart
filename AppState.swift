import SwiftUI
import Combine

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var appInputSourceMap: [String: String] = [:] {
        didSet {
            saveRules()
        }
    }

    // ...existing properties...

    init() {
        loadRules()
        // ...existing initialization code...
    }

    func saveRules() {
        UserDefaults.standard.set(appInputSourceMap, forKey: "AppInputSourceMap")
    }

    func loadRules() {
        if let map = UserDefaults.standard.dictionary(forKey: "AppInputSourceMap") as? [String: String] {
            appInputSourceMap = map
        }
    }

    // ...existing methods...
}