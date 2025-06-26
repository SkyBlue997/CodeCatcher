import SwiftUI
import AppKit

@MainActor
struct MenuBarView: View {
    @EnvironmentObject var codeManager: CodeManager
    @AppStorage("selectedTab") private var selectedTab: Int = 0
    
    var body: some View {
        VStack(spacing: 8) {
            // 标题
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.blue)
                Text("验证码捕手".localized)
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // 最近验证码
            if let latestCode = codeManager.recentCodes.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey.latestCode.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(latestCode.code)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            codeManager.copyToClipboard(latestCode.code)
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                        .help("复制验证码")
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                    
                    Text("来源: \(latestCode.source) · \(timeAgo(from: latestCode.timestamp))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 4)
            } else {
                HStack {
                    Text(LocalizedStringKey.noCode.localized)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            Divider()
            
            // 操作按钮
            VStack(spacing: 4) {
                Button(action: {
                    openMainWindow()
                }) {
                    HStack {
                        Image(systemName: "macwindow")
                        Text(LocalizedStringKey.openMainWindow.localized)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundColor(.primary)
                
                Button(action: {
                    NSApp.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text(LocalizedStringKey.quit.localized)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 250)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func openMainWindow() {
        // 关闭 popover
        StatusBarController.shared.closePopover()
        
        // 设置为普通应用模式以显示主窗口
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // 先尝试查找现有的主窗口
        var mainWindow: NSWindow?
        
        // 查找可能的主窗口
        for window in NSApp.windows {
            // 检查是否是 SwiftUI 的主窗口
            if window.contentViewController is NSHostingController<ContentView> {
                mainWindow = window
                break
            }
            // 检查窗口大小（主窗口应该是 600x800）
            else if window.frame.size.width == 600 && window.frame.size.height == 800 {
                mainWindow = window
                break
            }
            // 检查窗口是否有内容视图控制器且不是 popover
            else if window.contentViewController != nil && 
                    !(window.contentViewController is NSHostingController<MenuBarView>) &&
                    !window.title.isEmpty {
                mainWindow = window
                break
            }
        }
        
        if let window = mainWindow {
            // 找到主窗口，显示它
            window.makeKeyAndOrderFront(nil)
            window.center()
            window.orderFrontRegardless()
            print("✅ 找到并显示主窗口")
        } else {
            // 如果没有找到主窗口，尝试创建新的
            print("⚠️ 未找到主窗口，尝试通过菜单打开新窗口")
            
            // 尝试通过应用菜单打开新窗口
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 创建一个新的主窗口
                let contentView = ContentView()
                    .environmentObject(CodeManager.shared)
                    .environmentObject(NotificationManager())
                
                let hostingController = NSHostingController(rootView: contentView)
                let newWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 600, height: 800),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                
                newWindow.contentViewController = hostingController
                newWindow.title = "验证码捕手"
                newWindow.center()
                newWindow.makeKeyAndOrderFront(nil)
                newWindow.orderFrontRegardless()
                print("✅ 创建并显示新的主窗口")
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return "\(day)" + LocalizedStringKey.daysAgo.localized
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)" + LocalizedStringKey.hoursAgo.localized
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)" + LocalizedStringKey.minutesAgo.localized
        } else {
            return LocalizedStringKey.justNow.localized
        }
    }
}