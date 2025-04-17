import Foundation
import SwiftUI

// 支持的语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system" // 跟随系统
    case zhCN = "zh-CN"    // 简体中文
    case enUS = "en-US"    // 英文
    case jaJP = "ja-JP"    // 日语
    case koKR = "ko-KR"    // 韩语
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .zhCN: return "简体中文"
        case .enUS: return "English"
        case .jaJP: return "日本語"
        case .koKR: return "한국어"
        }
    }
    
    var locale: Locale {
        switch self {
        case .system: return Locale.current
        case .zhCN: return Locale(identifier: "zh-CN")
        case .enUS: return Locale(identifier: "en-US")
        case .jaJP: return Locale(identifier: "ja-JP")
        case .koKR: return Locale(identifier: "ko-KR")
        }
    }
    
    // 从系统语言获取最匹配的语言
    static func fromSystemLanguage() -> AppLanguage {
        let languageCode = Locale.current.language.languageCode?.identifier.lowercased() ?? ""
        let regionCode = Locale.current.region?.identifier.lowercased() ?? ""
        let fullCode = "\(languageCode)-\(regionCode)"
        
        // 检查完整语言代码匹配
        if fullCode.hasPrefix("zh-cn") || fullCode.hasPrefix("zh-hans") {
            return .zhCN
        } else if fullCode.hasPrefix("en") {
            return .enUS
        } else if fullCode.hasPrefix("ja") {
            return .jaJP
        } else if fullCode.hasPrefix("ko") {
            return .koKR
        }
        
        // 只检查语言代码
        if languageCode == "zh" {
            return .zhCN
        } else if languageCode == "en" {
            return .enUS
        } else if languageCode == "ja" {
            return .jaJP
        } else if languageCode == "ko" {
            return .koKR
        }
        
        // 默认使用英语
        return .enUS
    }
}

@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
            updateLocale()
        }
    }
    
    private var bundle: Bundle?
    
    init() {
        // 从存储中加载语言设置，默认跟随系统
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        self.currentLanguage = AppLanguage(rawValue: savedLanguage) ?? .system
        updateLocale()
    }
    
    private func updateLocale() {
        // 设置应用程序的语言环境
        if currentLanguage == .system {
            // 如果是跟随系统，使用系统语言或默认到英语
            let actualLanguage = AppLanguage.fromSystemLanguage()
            if let path = Bundle.main.path(forResource: actualLanguage.rawValue, ofType: "lproj"),
               let languageBundle = Bundle(path: path) {
                bundle = languageBundle
            } else {
                // 如果没有找到对应的语言包，使用英语
                if let path = Bundle.main.path(forResource: "en-US", ofType: "lproj"),
                   let languageBundle = Bundle(path: path) {
                    bundle = languageBundle
                } else {
                    bundle = nil
                }
            }
        } else {
            // 明确指定了语言
            if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
               let languageBundle = Bundle(path: path) {
                bundle = languageBundle
            } else {
                // 如果找不到指定的语言包，使用英语
                if let path = Bundle.main.path(forResource: "en-US", ofType: "lproj"),
                   let languageBundle = Bundle(path: path) {
                    bundle = languageBundle
                } else {
                    bundle = nil
                }
            }
        }
        
        // 通知观察者语言已更改
        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
    }
    
    // 本地化字符串
    func localizedString(_ key: String, comment: String = "") -> String {
        if let bundle = bundle {
            return NSLocalizedString(key, bundle: bundle, comment: comment)
        } else {
            return NSLocalizedString(key, comment: comment)
        }
    }
}

// MARK: - 全局函数用于本地化字符串
@MainActor
func localizedStringForKey(_ key: String) -> String {
    return LocalizationManager.shared.localizedString(key)
}

// MARK: - 扩展String以支持本地化
extension String {
    nonisolated var localized: String {
        // 对于非主线程的调用，使用标准本地化
        return NSLocalizedString(self, comment: "")
    }
    
    // 在主线程中使用这个版本
    @MainActor
    func localizedOnMain() -> String {
        return LocalizationManager.shared.localizedString(self)
    }
}

// MARK: - 本地化字符串键
struct LocalizedStringKey {
    static let historyTab = "history_tab"
    static let settingsTab = "settings_tab"
    static let aboutTab = "about_tab"
    static let latestCode = "latest_code"
    static let noCode = "no_code"
    static let copy = "copy"
    static let options = "options"
    static let openMainWindow = "open_main_window"
    static let settings = "settings"
    static let quit = "quit"
    static let recentCodes = "recent_codes"
    static let clearHistory = "clear_history"
    static let codeDetails = "code_details"
    static let source = "source"
    static let close = "close"
    static let justNow = "just_now"
    static let minutesAgo = "minutes_ago"
    static let hoursAgo = "hours_ago"
    static let daysAgo = "days_ago"
}

// 为了让预览支持本地化
struct LocalizedPreview<Content: View>: View {
    let content: Content
    let language: AppLanguage
    
    init(_ language: AppLanguage, @ViewBuilder content: () -> Content) {
        self.language = language
        self.content = content()
    }
    
    var body: some View {
        content
            .environment(\.locale, language.locale)
            .previewDisplayName(language.displayName)
    }
} 