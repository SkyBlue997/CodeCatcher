import Foundation
import ServiceManagement

/// 管理应用程序的开机自启动
class LaunchAtLogin {
    
    /// 应用程序的 bundle 标识符
    private static var bundleIdentifier: String? {
        return Bundle.main.bundleIdentifier
    }
    
    /// 检查应用程序是否设置了开机自启动
    static var isEnabled: Bool {
        if bundleIdentifier != nil {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    /// 启用开机自启动
    static func enable() {
        guard bundleIdentifier != nil else { return }
        
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("启用开机自启动失败: \(error.localizedDescription)")
        }
    }
    
    /// 禁用开机自启动
    static func disable() {
        guard bundleIdentifier != nil else { return }
        
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            print("禁用开机自启动失败: \(error.localizedDescription)")
        }
    }
    
    /// 切换开机自启动状态
    static func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }
} 