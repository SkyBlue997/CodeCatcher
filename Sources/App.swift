import SwiftUI
import Foundation
import AppKit

// 添加AppDelegate类来处理应用程序生命周期
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var windowCloseObserver: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为辅助应用模式，只显示状态栏，不在 Dock 中显示
        NSApp.setActivationPolicy(.accessory)
        
        // 在控制台打印日志，帮助诊断
        print("应用程序已启动，状态栏模式")
        
        // 初始化状态栏控制器
        statusBarController = StatusBarController.shared
        
        // 添加窗口关闭监听
        setupWindowCloseObserver()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理观察者
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupWindowCloseObserver() {
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            
            // 检查是否是主窗口关闭
            if window.contentViewController is NSHostingController<ContentView> ||
               window.title.contains("CodeCatcher") {
                
                // 延迟一点时间确保窗口完全关闭后再切换模式
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 检查是否还有其他主窗口打开
                    let hasMainWindows = NSApp.windows.contains { win in
                        win != window && (
                            win.contentViewController is NSHostingController<ContentView> ||
                            win.title.contains("CodeCatcher")
                        )
                    }
                    
                    // 如果没有其他主窗口，切换回辅助模式
                    if !hasMainWindows {
                        NSApp.setActivationPolicy(.accessory)
                        print("主窗口已关闭，切换回状态栏模式")
                    }
                }
            }
        }
    }
}

// 状态栏控制器，使用单例模式
@MainActor
class StatusBarController: NSObject {
    static let shared = StatusBarController()
    
    private var statusItem: NSStatusItem!
    private var codeManager: CodeManager?
    private var popover: NSPopover?
    
    private override init() {
        super.init()
        setupStatusItem()
        setupPopover()
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
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 260, height: 220)
        popover?.behavior = .transient
        popover?.animates = true
    }
    
    @MainActor
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            let menuView = MenuBarView().environmentObject(codeManager ?? CodeManager.shared)
            popover.contentViewController = NSHostingController(rootView: menuView)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    // 添加公共方法来关闭 popover
    @MainActor
    func closePopover() {
        popover?.performClose(nil)
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
                    // 设置状态栏控制器的codeManager
                    StatusBarController.shared.setCodeManager(codeManager)
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
} 