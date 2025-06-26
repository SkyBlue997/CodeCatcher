import Foundation
import UserNotifications
import AppKit

@MainActor
class NotificationManager: ObservableObject {
    @Published var isMonitoring = false
    @Published var statusMessage = "未开始监听通知"
    private var axObserver: AXObserver?
    private var permissionCheckTimer: Timer?
    
    init() {
        // 因调试环境无法使用UNUserNotificationCenter，所以使用简化的逻辑
        let isDebugEnvironment = Bundle.main.bundleIdentifier == nil || Bundle.main.bundleURL.path.contains("/.build/")
        
        if isDebugEnvironment {
            statusMessage = "调试环境中运行，通知功能受限"
        } else {
            // 在正式环境中将使用真实的通知中心
            statusMessage = "应用准备就绪"
            // 不在 init 中请求通知权限，改为在需要时请求
        }
    }
    
    deinit {
        // 清理定时器
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
    
    // 通知权限请求
    func requestNotificationPermission() {
        // 暂时禁用 UNUserNotificationCenter 以避免崩溃
        statusMessage = "通知功能已准备就绪"
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // 使用辅助功能 API 监听系统通知横幅
        guard checkAccessibilityPermission() else {
            statusMessage = "请在系统设置 ‣ 隐私与安全 ‣ 辅助功能 中授权 CodeCatcher"
            requestAccessibilityPermission()
            return
        }

        _ = AXUIElementCreateSystemWide()
        var observer: AXObserver?
        
        // 创建观察者回调
        let callback: AXObserverCallback = { observer, element, notification, userData in
            // 尝试获取元素的值
            var value: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
               let msg = value as? String {
                DispatchQueue.main.async {
                    CodeManager.shared.extractAndSaveCode(from: msg)
                }
            }
        }
        
        if AXObserverCreate(ProcessInfo.processInfo.processIdentifier, callback, &observer) == .success,
           let obs = observer {
            axObserver = obs
            CFRunLoopAddSource(CFRunLoopGetCurrent(),
                              AXObserverGetRunLoopSource(obs),
                              .defaultMode)
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWorkspaceNotification),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        isMonitoring = true
        statusMessage = "正在监听通知..."
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        if let obs = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                                  AXObserverGetRunLoopSource(obs),
                                  .defaultMode)
            axObserver = nil
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        
        // 清理权限检查定时器
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        
        isMonitoring = false
        statusMessage = "已停止监听通知"
    }
    
    @objc private func handleWorkspaceNotification(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let appName = app.localizedName {
            print("应用程序激活: \(appName)")
        }
    }
}

// 在实际应用中，我们需要使用NSAccessibility APIs 来读取通知内容
// 这需要用户在系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能中授权
extension NotificationManager {
    // 安全地检查辅助功能权限
    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    // 检查完全磁盘访问权限（用于访问短信数据库）
    @MainActor
    func checkFullDiskAccessPermission() -> Bool {
        // 使用 SMSMonitor 来检查权限
        let smsMonitor = SMSMonitor()
        return smsMonitor.hasPermission
    }
    
    @MainActor
    func requestAccessibilityPermission() {
        // 使用不同的方法请求权限，避免并发问题
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        
        // 清理现有定时器
        permissionCheckTimer?.invalidate()
        
        // 设置定时器检查权限是否生效
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.checkAccessibilityPermission() {
                    self.permissionCheckTimer?.invalidate()
                    self.permissionCheckTimer = nil
                    self.statusMessage = "辅助功能权限已生效，建议重启应用以确保正常工作"
                }
            }
        }
    }
    
    @MainActor
    func requestFullDiskAccessPermission() {
        // 打开系统偏好设置的完全磁盘访问权限页面
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
} 