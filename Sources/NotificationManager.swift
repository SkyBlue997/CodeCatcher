import Foundation
import UserNotifications
import AppKit

@MainActor
class NotificationManager: ObservableObject {
    @Published var isMonitoring = false
    @Published var statusMessage = "未开始监听通知"
    
    // 移除UNUserNotificationCenter的直接使用
    private var notificationEnabled = false
    
    init() {
        // 因调试环境无法使用UNUserNotificationCenter，所以使用简化的逻辑
        let isDebugEnvironment = Bundle.main.bundleIdentifier == nil || Bundle.main.bundleURL.path.contains("/.build/")
        
        if isDebugEnvironment {
            statusMessage = "调试环境中运行，通知功能受限"
            notificationEnabled = true
        } else {
            // 在正式环境中将使用真实的通知中心
            statusMessage = "应用准备就绪"
            notificationEnabled = true
        }
    }
    
    // 通知权限请求模拟
    func requestNotificationPermission() {
        // 在调试环境中直接假设权限已授予
        DispatchQueue.main.async {
            self.statusMessage = "已获取通知权限（模拟）"
        }
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // 注册通知中心观察者
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleNotification),
            name: NSNotification.Name("com.apple.notification.center"),
            object: nil
        )
        
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
        
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        
        isMonitoring = false
        statusMessage = "已停止监听通知"
    }
    
    @objc private func handleNotification(_ notification: Notification) {
        // 此处仅为示例，实际上系统限制了对通知内容的访问
        // 在macOS中，我们需要使用辅助功能权限才能读取通知内容
        
        if let userInfo = notification.userInfo,
           let message = userInfo["message"] as? String {
            // 检查消息是否包含验证码
            Task { @MainActor in
                CodeManager.shared.extractAndSaveCode(from: message)
            }
        }
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
        // 尝试读取短信数据库位置，如果能读取则表示有权限
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let smsDbPath = homeDir.appendingPathComponent("Library/Messages/chat.db")
        return FileManager.default.isReadableFile(atPath: smsDbPath.path)
    }
    
    @MainActor
    func requestAccessibilityPermission() {
        // 使用不同的方法请求权限，避免并发问题
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    @MainActor
    func requestFullDiskAccessPermission() {
        // 打开系统偏好设置的完全磁盘访问权限页面
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // 增强通知处理，直接监听系统短信数据库变化
    @MainActor
    func setupSMSMonitoring() {
        guard checkFullDiskAccessPermission() else {
            statusMessage = "需要完全磁盘访问权限来监听短信"
            return
        }
        
        // 这里可以添加监控短信数据库的代码
        // 例如使用SQLite读取chat.db文件
        
        // 示例代码（实际实现需要更复杂的SQLite操作）
        Task {
            // 定期检查短信数据库变化
            await checkForNewSMS()
        }
        
        statusMessage = "已启用短信监听"
    }
    
    @MainActor
    private func checkForNewSMS() async {
        // 实际项目中需要实现SQLite查询最新短信
        // 这只是一个简化的示例
        
        // 创建定时器，每5秒检查一次
        for await _ in AsyncStream<Void>(unfolding: { 
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return () 
        }) {
            guard self.checkFullDiskAccessPermission() else { continue }
            
            // 在实际应用中，这里会查询数据库获取新短信
            // 为了示例，我们只是打印一条日志
            print("检查新短信...")
        }
    }
} 