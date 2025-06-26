import Foundation
import SQLite3

@MainActor
class SMSMonitor: ObservableObject {
    @Published var isMonitoring = false
    @Published var hasPermission = false
    
    private var monitorTimer: Timer?
    private var lastCheckedID: Int64 = 0
    private let smsDbPath: String
    
    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        smsDbPath = homeDir.appendingPathComponent("Library/Messages/chat.db").path
        
        // 检查权限
        checkPermission()
        
        // 从 UserDefaults 恢复上次检查的ID
        lastCheckedID = Int64(UserDefaults.standard.integer(forKey: "lastCheckedSMSID"))
    }
    
    func checkPermission() {
        hasPermission = FileManager.default.isReadableFile(atPath: smsDbPath)
    }
    
    func startMonitoring() {
        guard hasPermission else {
            print("没有完全磁盘访问权限，无法监控短信")
            return
        }
        
        isMonitoring = true
        
        // 立即执行一次检查
        checkForNewSMS()
        
        // 设置定时器，每5秒检查一次
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForNewSMS()
            }
        }
    }
    
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }
    
    private func checkForNewSMS() {
        var db: OpaquePointer?
        
        // 打开数据库
        if sqlite3_open_v2(smsDbPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            print("无法打开短信数据库")
            return
        }
        
        defer {
            sqlite3_close(db)
        }
        
        // 查询最新的短信
        let query = """
            SELECT message.ROWID, message.text, message.date
            FROM message
            WHERE message.ROWID > ?
            AND message.text IS NOT NULL
            AND message.text != ''
            ORDER BY message.ROWID DESC
            LIMIT 50
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            print("无法准备SQL语句")
            return
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        // 绑定参数
        sqlite3_bind_int64(statement, 1, lastCheckedID)
        
        var newMessages: [(id: Int64, text: String, date: Date)] = []
        
        // 执行查询
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)
            
            if let textPointer = sqlite3_column_text(statement, 1) {
                let text = String(cString: textPointer)
                let dateValue = sqlite3_column_int64(statement, 2)
                
                // iOS/macOS 的短信日期是从 2001-01-01 开始的纳秒数
                let date = Date(timeIntervalSinceReferenceDate: Double(dateValue) / 1_000_000_000)
                
                newMessages.append((id: id, text: text, date: date))
                
                // 更新最后检查的ID
                if id > lastCheckedID {
                    lastCheckedID = id
                }
            }
        }
        
        // 保存最后检查的ID
        UserDefaults.standard.set(lastCheckedID, forKey: "lastCheckedSMSID")
        
        // 处理新短信
        for message in newMessages.reversed() {
            print("新短信 (ID: \(message.id)): \(message.text)")
            
            // 尝试提取验证码
            if let code = CodeManager.shared.extractCode(from: message.text) {
                print("从短信中提取到验证码: \(code)")
                
                // 保存验证码
                let verificationCode = VerificationCode(
                    code: code,
                    source: "短信",
                    timestamp: message.date
                )
                
                CodeManager.shared.recentCodes.insert(verificationCode, at: 0)
                CodeManager.shared.saveCodesToStorage()
                
                // 如果启用了自动复制
                if CodeManager.shared.autoClipboard {
                    CodeManager.shared.copyToClipboard(code)
                }
            }
        }
    }
} 