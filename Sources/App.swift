import SwiftUI
import Foundation
import AppKit

// 添加AppDelegate类来处理应用程序生命周期
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保应用为普通应用（而不是后台应用或其他类型）
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // 在控制台打印日志，帮助诊断
        print("应用程序已启动，窗口即将显示")
        
        // 初始化状态栏控制器
        statusBarController = StatusBarController.shared
    }
}

// 状态栏控制器，使用单例模式
@MainActor
class StatusBarController: NSObject {
    static let shared = StatusBarController()
    
    private var statusItem: NSStatusItem!
    private var codeManager: CodeManager?
    
    private override init() {
        super.init()
        setupStatusItem()
    }
    
    func setCodeManager(_ manager: CodeManager) {
        self.codeManager = manager
    }
    
    @MainActor
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // 设置图标
            if let image = NSImage(systemSymbolName: "shield.fill", accessibilityDescription: "验证码捕手") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "🔑"
            }
            
            // 设置点击行为
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }
    
    @MainActor
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard statusItem.button != nil else { return }
        
        let menuView = NSHostingView(rootView: MenuBarView().environmentObject(codeManager ?? CodeManager.shared))
        menuView.frame = NSRect(x: 0, y: 0, width: 250, height: 200)
        
        let menu = NSMenu()
        let menuItem = NSMenuItem()
        menuItem.view = menuView
        menu.addItem(menuItem)
        
        // 添加退出选项
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }
}

@main
struct CodeCatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var codeManager = CodeManager()
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var appearanceManager = AppearanceManager.shared
    
    init() {
        setupApplication()
        // 设置状态栏控制器的codeManager
        Task { @MainActor in
            StatusBarController.shared.setCodeManager(codeManager)
        }
    }
    
    private func setupApplication() {
        if Bundle.main.bundleIdentifier == nil || Bundle.main.bundleIdentifier?.isEmpty == true {
            print("警告: 应用在非正常应用束环境中运行")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationManager)
                .environmentObject(codeManager)
                .frame(width: 600, height: 800)
                .fixedSize(horizontal: true, vertical: true)
                .background(Color(NSColor.windowBackgroundColor))
                .onAppear {
                    print("主窗口视图已加载")
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        // 不再使用SwiftUI的MenuBarExtra，改为自定义NSStatusItem
    }
} 