import Foundation
import AppKit

@MainActor
class CodeManager: ObservableObject {
    static let shared = CodeManager()
    
    @Published var recentCodes: [VerificationCode] = []
    @Published var lastExtractedCode: String?
    @Published var autoClipboard: Bool = true
    @Published var clipboardCheckInterval: Double = 3.0
    @Published var isMonitoringClipboard: Bool = false
    @Published var historyRetentionHours: Double = 48.0 // 默认48小时
    
    /// 允许半角与全角数字，长度 4–8
    private let codePattern = "(?:[0-9０-９]{4,8})"
    /// 将全角数字转半角，并统一空白字符/破折号为半角空格，方便后续解析
    private func normalize(_ text: String) -> String {
        let halfWidth = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        return halfWidth.replacingOccurrences(of: "[\\u{00A0}\\u{3000}]", with: " ", options: .regularExpression)
    }
    private let commonPrefixes = ["验证码", "code", "验证", "校验码", "認証", "인증", "コード"]
    private var clipboardTimer: Timer?
    private var lastClipboardContent: String = ""
    private var cleanupTimer: Timer?
    
    // 添加AI检测器引用
    private let aiDetector = AICodeDetector.shared
    
    init() {
        loadSettings()
        loadSavedCodes()
        scheduleCleanup()
    }
    
    func loadSettings() {
        let defaults = UserDefaults.standard
        autoClipboard = defaults.bool(forKey: "autoClipboard")
        clipboardCheckInterval = defaults.double(forKey: "clipboardCheckInterval")
        if clipboardCheckInterval == 0 {
            clipboardCheckInterval = 3.0 // 默认3秒
        }
        isMonitoringClipboard = defaults.bool(forKey: "isMonitoringClipboard")
        
        historyRetentionHours = defaults.double(forKey: "historyRetentionHours")
        if historyRetentionHours == 0 {
            historyRetentionHours = 48.0 // 默认48小时
        }
        
        // 如果之前设置了监控剪贴板，自动启动
        if isMonitoringClipboard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startMonitoringClipboard()
            }
        }
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(autoClipboard, forKey: "autoClipboard")
        defaults.set(clipboardCheckInterval, forKey: "clipboardCheckInterval")
        defaults.set(isMonitoringClipboard, forKey: "isMonitoringClipboard")
        defaults.set(historyRetentionHours, forKey: "historyRetentionHours")
    }
    
    func loadSavedCodes() {
        if let data = UserDefaults.standard.data(forKey: "savedCodes"),
           let savedCodes = try? JSONDecoder().decode([VerificationCode].self, from: data) {
            self.recentCodes = savedCodes
            // 加载后立即清理过期记录
            cleanupExpiredCodes()
        }
    }
    
    func saveCodesToStorage() {
        if let encodedData = try? JSONEncoder().encode(recentCodes) {
            UserDefaults.standard.set(encodedData, forKey: "savedCodes")
        }
    }
    
    // 设置历史记录保留时间
    func updateHistoryRetention(_ hours: Double) {
        historyRetentionHours = hours
        saveSettings()
        cleanupExpiredCodes() // 立即执行一次清理
        scheduleCleanup() // 重新安排定时清理
    }
    
    // 清理过期的验证码
    func cleanupExpiredCodes() {
        let cutoffDate = Date().addingTimeInterval(-historyRetentionHours * 3600)
        let oldCount = recentCodes.count
        
        recentCodes = recentCodes.filter { $0.timestamp > cutoffDate }
        
        if oldCount != recentCodes.count {
            saveCodesToStorage() // 只在有实际变化时保存
        }
    }
    
    // 安排定时清理任务
    private func scheduleCleanup() {
        cleanupTimer?.invalidate()
        
        // 每小时清理一次
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupExpiredCodes()
            }
        }
    }
    
    // 开始监控剪贴板
    func startMonitoringClipboard() {
        guard clipboardTimer == nil else { return }
        
        // 先获取当前剪贴板内容作为基线
        if let currentContent = NSPasteboard.general.string(forType: .string) {
            lastClipboardContent = currentContent
        }
        
        // 创建定时器
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: clipboardCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
        
        isMonitoringClipboard = true
        saveSettings()
    }
    
    // 停止监控剪贴板
    func stopMonitoringClipboard() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        isMonitoringClipboard = false
        saveSettings()
    }
    
    // 更新剪贴板检查间隔
    func updateClipboardCheckInterval(_ newInterval: Double) {
        clipboardCheckInterval = newInterval
        saveSettings()
        
        // 如果正在监控，重启监控以应用新间隔
        if isMonitoringClipboard {
            stopMonitoringClipboard()
            startMonitoringClipboard()
        }
    }
    
    // 检查剪贴板内容
    private func checkClipboard() {
        // 先检查文本内容
        if let clipboardContent = NSPasteboard.general.string(forType: .string),
           clipboardContent != lastClipboardContent {
            lastClipboardContent = clipboardContent
            
            // 尝试提取验证码
            if let _ = extractCode(from: clipboardContent) {
                extractAndSaveCode(from: clipboardContent)
                return
            }
        }
        
        // 检查图像内容
        Task { @MainActor in
            if let code = await VisionCodeDetector.shared.checkClipboardForImage() {
                self.lastExtractedCode = code
                
                // 添加到历史记录
                let newCode = VerificationCode(
                    code: code,
                    source: "图像",
                    timestamp: Date()
                )
                
                self.recentCodes.insert(newCode, at: 0)
                
                // 限制保存的验证码数量
                if self.recentCodes.count > 20 {
                    self.recentCodes = Array(self.recentCodes.prefix(20))
                }
                
                // 保存到存储
                self.saveCodesToStorage()
                
                // 自动复制到剪贴板
                if self.autoClipboard {
                    self.copyToClipboard(code)
                }
            }
        }
    }
    
    func extractAndSaveCode(from text: String) {
        guard let extractedCode = extractCode(from: text) else { return }
        
        DispatchQueue.main.async {
            self.lastExtractedCode = extractedCode
            
            // 添加到历史记录
            let newCode = VerificationCode(
                code: extractedCode,
                source: self.determineSource(text),
                timestamp: Date()
            )
            
            self.recentCodes.insert(newCode, at: 0)
            
            // 限制保存的验证码数量
            if self.recentCodes.count > 20 {
                self.recentCodes = Array(self.recentCodes.prefix(20))
            }
            
            // 保存到存储
            self.saveCodesToStorage()
            
            // 自动复制到剪贴板
            if self.autoClipboard {
                self.copyToClipboard(extractedCode)
            }
        }
    }
    
    func extractCode(from text: String) -> String? {
        let normalizedText = normalize(text)
        // 先尝试使用AI检测
        if let aiCode = aiDetector.detectVerificationCode(in: text) {
            print("AI检测到验证码: \(aiCode)")
            return aiCode
        }
        
        // 如果AI检测失败，回退到正则表达式方法
        // 尝试在文本中找到常见的验证码前缀
        for prefix in commonPrefixes {
            if let range = normalizedText.range(of: prefix, options: .caseInsensitive) {
                let startIndex = range.upperBound
                let remainingText = String(normalizedText[startIndex...])
                
                // 使用正则表达式提取验证码
                if let regex = try? NSRegularExpression(pattern: codePattern, options: []),
                   let match = regex.firstMatch(in: remainingText, options: [], range: NSRange(remainingText.startIndex..., in: remainingText)) {
                    let matchedRange = Range(match.range, in: remainingText)!
                    let code = String(remainingText[matchedRange])
                    return code.replacingOccurrences(of: "[\\s-]", with: "", options: .regularExpression)
                }
            }
        }
        
        // 如果没有找到前缀，尝试直接找验证码格式
        if let regex = try? NSRegularExpression(pattern: codePattern, options: []),
           let match = regex.firstMatch(in: normalizedText, options: [], range: NSRange(normalizedText.startIndex..., in: normalizedText)) {
            let matchedRange = Range(match.range, in: normalizedText)!
            let code = String(normalizedText[matchedRange])
            return code.replacingOccurrences(of: "[\\s-]", with: "", options: .regularExpression)
        }
        
        return nil
    }
    
    func determineSource(_ text: String) -> String {
        if text.contains("短信") || text.contains("信息") {
            return "短信"
        } else if text.contains("邮件") || text.contains("email") {
            return "邮件"
        } else {
            return "通知"
        }
    }
    
    func copyToClipboard(_ code: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
    }
    
    func clearHistory() {
        recentCodes.removeAll()
        saveCodesToStorage()
    }
    
    // 应用终止时清理资源
    @MainActor
    func willTerminate() {
        clipboardTimer?.invalidate()
        cleanupTimer?.invalidate()
        clipboardTimer = nil
        cleanupTimer = nil
    }
}

struct VerificationCode: Codable, Identifiable, Sendable {
    var id = UUID()
    let code: String
    let source: String
    let timestamp: Date
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
} 