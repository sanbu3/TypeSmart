import Foundation
import InputMethodKit
import SwiftUI

// Define a struct to hold detailed input source information
struct InputSourceInfo: Hashable, Identifiable {
    let id: String
    let localizedName: String
    let languages: [String]
    // let category: String // Optional: if we decide to use kTISPropertyInputSourceCategory
}

// Enum to represent the language mode of an input source
enum LanguageMode {
    case chinese
    case english
    case other
    case undetermined
}

class InputSourceManager {
    static let shared = InputSourceManager()
    
    // 添加对 SwitchRecordManager 的引用
    private let recordManager = SwitchRecordManager.shared

    private init() {}

    // Updated function to return [InputSourceInfo]
    func getInputSources() -> [InputSourceInfo] {
        print("[InputSourceManager] getInputSources: Fetching all input sources.")
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            print("[InputSourceManager] getInputSources: Failed to retrieve any input sources from TISCreateInputSourceList.")
            return []
        }
        print("[InputSourceManager] getInputSources: Retrieved \(sources.count) raw sources. Now filtering.")

        var detailedSources: [InputSourceInfo] = []
        // Define the expected type strings correctly
        let expectedKeyboardLayoutType = "TISTypeKeyboardLayout" // Value for kTISTypeKeyboardLayout
        let expectedInputModeType = "TISTypeKeyboardInputMode" // Value for kTISTypeInputMode

        for source in sources {
            guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                  let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else {
                print("[InputSourceManager] getInputSources: Skipping source due to missing ID or Name property.")
                continue
            }
            
            let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            let localizedName = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
            
            var sourceTypeString: String? = nil
            if let typePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) {
                sourceTypeString = Unmanaged<CFString>.fromOpaque(typePtr).takeUnretainedValue() as String
            }
            print("[InputSourceManager] getInputSources: Processing raw source: '\(localizedName)' (ID: \(id)), Actual Type: '\(sourceTypeString ?? "<Type N/A>")'")

            // Filter 1: Check if select-capable
            if let isSelectCapablePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) {
                let capable = Unmanaged<CFBoolean>.fromOpaque(isSelectCapablePtr).takeUnretainedValue()
                if !CFBooleanGetValue(capable) {
                    print("[InputSourceManager] getInputSources: -> Skipping non-selectable source: '\(localizedName)' (ID: \(id))")
                    continue
                }
            } else {
                print("[InputSourceManager] getInputSources: -> Warning: kTISPropertyInputSourceIsSelectCapable not found for '\(localizedName)' (ID: \(id)). Assuming not selectable and skipping.")
                continue
            }
            print("[InputSourceManager] getInputSources:    PASS: IsSelectCapable for '\(localizedName)'")

            // Compare with the expected type strings
            if sourceTypeString != expectedKeyboardLayoutType && sourceTypeString != expectedInputModeType {
                print("[InputSourceManager] getInputSources: -> Skipping source '\(localizedName)' (ID: \(id)) due to incompatible type: '\(sourceTypeString ?? "<Type N/A>")'. Expected '\(expectedKeyboardLayoutType)' or '\(expectedInputModeType)'.")
                continue
            }
            print("[InputSourceManager] getInputSources:    PASS: Type is compatible for '\(localizedName)' (Type: \(sourceTypeString ?? "N/A"))")
            
            var languages: [String] = []
            if let langPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
                if let langArray = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as? [String] {
                    languages = langArray
                }
            }

            let lowercasedID = id.lowercased()
            // Refined exclusion list
            let excludedIDKeywords = ["pressandhold", "handwriting", "voicecontrol", "emoji", "characterpalette", "virtualkeyboard", "dictation"]
            var skipBasedOnID = false
            for keyword in excludedIDKeywords {
                if lowercasedID.contains(keyword) {
                    print("[InputSourceManager] getInputSources: -> Skipping utility source: '\(localizedName)' (ID: \(id)) based on ID keyword: '\(keyword)'.")
                    skipBasedOnID = true
                    break
                }
            }
            if skipBasedOnID { continue }
            print("[InputSourceManager] getInputSources:    PASS: Not a known utility ID for '\(localizedName)'")
            
            print("[InputSourceManager] getInputSources: +++ Adding source: '\(localizedName)' (ID: \(id)), Type: \(sourceTypeString ?? "N/A"), Languages: \(languages)")
            detailedSources.append(InputSourceInfo(id: id, localizedName: localizedName, languages: languages))
        }
        print("[InputSourceManager] getInputSources: Finished filtering. Returning \(detailedSources.count) detailed sources.")
        return detailedSources
    }

    func getLanguageMode(for inputSource: TISInputSource) -> LanguageMode {
        guard let langProperty = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceLanguages) else {
            // Fallback to ID check if languages property is not available
            guard let idPtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
                return .undetermined
            }
            let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            return getModeFromInputSourceID(id)
        }

        guard let languages = Unmanaged<CFArray>.fromOpaque(langProperty).takeUnretainedValue() as? [String], !languages.isEmpty else {
            // Fallback to ID check if languages array is empty
            guard let idPtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
                return .undetermined
            }
            let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            return getModeFromInputSourceID(id)
        }

        for langCode in languages {
            let lowercasedLang = langCode.lowercased()
            if lowercasedLang.hasPrefix("zh") {
                return .chinese
            }
            if lowercasedLang.hasPrefix("en") || lowercasedLang == "abc" { // "abc" is often used for basic English
                return .english
            }
        }
        // If no primary match, check ID as a final fallback before .other
        guard let idPtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
            return .other // Or .undetermined if ID is crucial and missing
        }
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        let modeFromID = getModeFromInputSourceID(id)
        return modeFromID == .undetermined ? .other : modeFromID
    }

    func getLanguageMode(for inputSourceID: String) -> LanguageMode {
        guard let sources = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] else {
            return .undetermined
        }
        if let source = sources.first(where: { src in
            guard let idPtr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return false }
            return (Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String) == inputSourceID
        }) {
            return getLanguageMode(for: source)
        }
        // If source not found by ID directly, try heuristic on ID string itself
        return getModeFromInputSourceID(inputSourceID)
    }
    
    // Helper to infer mode from ID string as a fallback
    private func getModeFromInputSourceID(_ id: String) -> LanguageMode {
        let lowercasedID = id.lowercased()
        // Keywords for Chinese input methods (examples, may need expansion)
        if lowercasedID.contains("pinyin") || lowercasedID.contains("shuangpin") || 
           lowercasedID.contains("scim") || lowercasedID.contains("imkcn") || 
           lowercasedID.contains("chinese") || lowercasedID.contains("hans") || lowercasedID.contains("hant") {
            return .chinese
        }
        // Keywords for English input methods
        if lowercasedID.contains("abc") || lowercasedID.contains("english") || 
           lowercasedID.contains("us") || lowercasedID.contains("keylayout.english") {
            return .english
        }
        return .undetermined
    }

    func getCurrentInputLanguageMode() -> LanguageMode {
        guard let currentSourceUnmanaged = TISCopyCurrentKeyboardInputSource() else {
            return .undetermined
        }
        let currentSource = currentSourceUnmanaged.takeRetainedValue()
        return getLanguageMode(for: currentSource)
    }

    // Keep this for now if ContentView relies on it, but plan to phase out or adapt
    func getInputSourceNames() -> [String] {
        return getInputSources().map { $0.localizedName }
    }
    
    // Keep this for now if ContentView relies on it, but plan to phase out or adapt
    func getInputSourceIDs() -> [String] {
        return getInputSources().map { $0.id }
    }

    // 记录应用间切换，此方法应由 AppDelegate 调用
    func recordAppSwitch(fromAppID: String, toAppID: String, targetInputSourceID: String) {
        // fromInputSourceID 会在 switchInputSource 内部获取，这里不需要重复获取
        
        // 尝试切换，记录在 switchInputSource 内部进行
        switchInputSource(to: targetInputSourceID, fromAppID: fromAppID, toAppID: toAppID)
    }
    
    // 切换输入法并记录结果
    func switchInputSource(to targetID: String, fromAppID: String = "unknown", toAppID: String = "unknown") {
        print("[InputSourceManager] 尝试切换到输入法，ID: \(targetID)")

        // 获取当前输入法
        guard let currentSourceTIS = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            print("[InputSourceManager] 无法获取当前输入法。")
            // 记录失败的切换
            recordManager.addRecord(
                fromAppID: fromAppID,
                toAppID: toAppID,
                fromInputSourceID: "unknown",
                toInputSourceID: targetID,
                isSuccessful: false
            )
            return
        }

        // 获取当前输入法ID
        var currentSourceID = ""
        if let currentIDPtr = TISGetInputSourceProperty(currentSourceTIS, kTISPropertyInputSourceID) {
            currentSourceID = Unmanaged<CFString>.fromOpaque(currentIDPtr).takeUnretainedValue() as String
            print("[InputSourceManager] 当前输入法ID: \(currentSourceID)")
        } else {
            print("[InputSourceManager] 无法获取当前输入法ID属性。")
            currentSourceID = "unknown"
        }
        
        // 如果目标输入法已经是当前活动的输入法，则跳过
        if currentSourceID == targetID {
            print("[InputSourceManager] 目标输入法ID \(targetID) 已经是活动的。无需切换。")
            // 记录"成功"的切换（虽然实际上没有切换）
            recordManager.addRecord(
                fromAppID: fromAppID,
                toAppID: toAppID,
                fromInputSourceID: currentSourceID,
                toInputSourceID: targetID,
                isSuccessful: true
            )
            return
        }

        // 获取所有可用的输入法
        let inputSourcesCFArray = TISCreateInputSourceList(nil, false)
        guard let inputSources = inputSourcesCFArray?.takeRetainedValue() as? [TISInputSource] else {
            print("[InputSourceManager] 错误: 无法获取可用输入法列表。")
            return
        }
        
        print("[InputSourceManager] 找到 \(inputSources.count) 个可用输入法，正在查找目标输入法: \(targetID)")
        
        // 查找目标输入法
        guard let targetSource = inputSources.first(where: {
            var sourceID = ""
            if let idPtr = TISGetInputSourceProperty($0, kTISPropertyInputSourceID) {
                sourceID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            }
            return sourceID == targetID
        }) else {
            print("[InputSourceManager] 错误: 在可用列表中找不到目标输入法，ID: \(targetID)")
            // 记录所有可用的输入法信息，帮助调试
            print("[InputSourceManager] 可用的输入法列表:")
            for source in inputSources {
                var sID = "UnknownID"
                var sName = "UnknownName"
                if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                    sID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
                }
                if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
                    sName = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
                }
                print("[InputSourceManager] - ID: \(sID), Name: \(sName)")
            }
            return
        }
        
        print("[InputSourceManager] 已找到目标输入法。尝试 TISSelectInputSource...")
        let status = TISSelectInputSource(targetSource)
        
        if status == noErr {
            print("[InputSourceManager] 成功选择输入法 ID: \(targetID). 状态: noErr (\(status))")
            // 验证步骤 - 添加延迟检查以确保切换成功
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // 稍微增加延迟以确保系统更新
                if let newCurrentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
                    var newCurrentSourceID = "ErrorFetchingID"
                    var newCurrentSourceName = "ErrorFetchingName"

                    if let idPtr = TISGetInputSourceProperty(newCurrentSource, kTISPropertyInputSourceID) {
                        newCurrentSourceID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
                    }
                    if let namePtr = TISGetInputSourceProperty(newCurrentSource, kTISPropertyLocalizedName) {
                        newCurrentSourceName = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
                    }
                    print("[InputSourceManager] Verified: Current input source is now ID: \(newCurrentSourceID), Name: \(newCurrentSourceName)")
                    
                    let isSuccessful = (newCurrentSourceID == targetID)
                    if !isSuccessful {
                        print("[InputSourceManager] WARNING: Verification shows current ID (\(newCurrentSourceID)) does not match target ID (\(targetID)). Switch might have failed or reverted.")
                    }
                    
                    // 记录切换结果
                    self.recordManager.addRecord(
                        fromAppID: fromAppID,
                        toAppID: toAppID,
                        fromInputSourceID: currentSourceID,
                        toInputSourceID: targetID,
                        isSuccessful: isSuccessful
                    )
                } else {
                    print("[InputSourceManager] Selected input source, but failed to verify current source afterwards.")
                    
                    // 无法验证，假设成功
                    self.recordManager.addRecord(
                        fromAppID: fromAppID,
                        toAppID: toAppID,
                        fromInputSourceID: currentSourceID,
                        toInputSourceID: targetID,
                        isSuccessful: true
                    )
                }
            }
        } else {
            print("[InputSourceManager] Error selecting input source ID: \(targetID). Status: \(status).")
            
            // 记录失败的切换
            recordManager.addRecord(
                fromAppID: fromAppID,
                toAppID: toAppID,
                fromInputSourceID: currentSourceID,
                toInputSourceID: targetID,
                isSuccessful: false
            )
        }
    }
    
    // 添加一个新的方法来切换到指定的输入法
    func switchToInputSource(withID id: String) -> Bool {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            print("[InputSourceManager] switchToInputSource: 无法获取输入源列表。")
            return false
        }

        for source in sources {
            guard let sourceIDPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
                continue
            }
            let sourceID = Unmanaged<CFString>.fromOpaque(sourceIDPtr).takeUnretainedValue() as String

            if sourceID == id {
                let status = TISSelectInputSource(source)
                if status == noErr {
                    print("[InputSourceManager] switchToInputSource: 成功切换到输入源 \(id)。")
                    return true
                } else {
                    print("[InputSourceManager] switchToInputSource: 切换到输入源 \(id) 失败，错误码：\(status)。")
                    return false
                }
            }
        }

        print("[InputSourceManager] switchToInputSource: 未找到匹配的输入源 \(id)。")
        return false
    }
    
    func getCurrentInputSourceID() -> String? {
        // TISCopyCurrentKeyboardInputSource() 返回 Unmanaged<TISInputSource>!
        // 必须先检查它是否为 nil，然后再调用 takeRetainedValue()。
        guard let unmanagedCurrentSource = TISCopyCurrentKeyboardInputSource() else {
            // TISCopyCurrentKeyboardInputSource() 调用本身返回了 nil。
            print("获取当前键盘输入源引用失败。")
            return nil
        }
        // 现在 unmanagedCurrentSource 是一个非 nil 的 Unmanaged<TISInputSource>。
        // 调用 takeRetainedValue() 来获取实际的 TISInputSource 对象。
        let currentSource: TISInputSource = unmanagedCurrentSource.takeRetainedValue()

        // TISGetInputSourceProperty 返回 UnsafeRawPointer! (这是可选的)。
        // 所以这个 guard let 是正确的。
        guard let pointerToID = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) else {
            print("从当前输入源获取 kTISPropertyInputSourceID 失败。")
            return nil
        }
        // pointerToID 现在是 UnsafeRawPointer (非可选)。
        // 将它转换为 CFString，然后再转换为 Swift String。
        let inputSourceID = Unmanaged<CFString>.fromOpaque(pointerToID).takeUnretainedValue() as String
        return inputSourceID
    }
}
