import Foundation
import SwiftUI
import AppKit

// 外观模式
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "system"  // 跟随系统
    case light = "light"    // 浅色模式
    case dark = "dark"      // 深色模式
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }
    
    // 转换为NSAppearanceName
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil // 返回nil表示跟随系统
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    @Published var currentAppearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(currentAppearance.rawValue, forKey: "appAppearance")
            updateAppearance()
        }
    }
    
    init() {
        // 从存储中加载外观设置，默认跟随系统
        let savedAppearance = UserDefaults.standard.string(forKey: "appAppearance") ?? "system"
        self.currentAppearance = AppAppearance(rawValue: savedAppearance) ?? .system
        updateAppearance()
    }
    
    @MainActor
    private func updateAppearance() {
        // 应用程序的外观模式
        if let appearance = currentAppearance.nsAppearance {
            NSApp.appearance = appearance
        } else {
            NSApp.appearance = nil // 跟随系统
        }
    }
} 