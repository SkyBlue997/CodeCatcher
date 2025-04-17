import SwiftUI
import AppKit

@MainActor
struct MenuBarView: View {
    @EnvironmentObject var codeManager: CodeManager
    @Environment(\.openWindow) private var openWindow
    @AppStorage("selectedTab") private var selectedTab: Int = 0
    
    // 将statusItem移到结构体内部并标记为MainActor隔离
    static let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    // 初始化设置状态栏图标
    init() {
        MenuBarView.configureStatusItem()
    }
    
    // 配置状态栏图标
    static func configureStatusItem() {
        if let button = statusItem.button {
            // 直接使用系统图标
            if let image = NSImage(systemSymbolName: "shield.fill", accessibilityDescription: "验证码捕手") {
                image.isTemplate = true  // 确保图标是单色的
                button.image = image
                print("✅ 已设置系统图标: shield.fill")
            } else {
                // 如果系统图标加载失败，使用emoji作为备用
                button.title = "🔑"
                print("⚠️ 系统图标加载失败，使用emoji替代")
            }
        }
    }
    
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
            
            // 操作按钮 - 简化二级菜单
            Menu {
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    openMainWindow()
                }) {
                    Label(LocalizedStringKey.openMainWindow.localized, systemImage: "macwindow")
                }
                
                Divider()
                
                Button(action: {
                    NSApp.terminate(nil)
                }) {
                    Label(LocalizedStringKey.quit.localized, systemImage: "power")
                }
            } label: {
                Label(LocalizedStringKey.options.localized, systemImage: "ellipsis.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            
        }
        .padding()
        .frame(width: 250)
    }
    
    private func openMainWindow() {
        if let window = NSApp.windows.first(where: { !($0.identifier?.rawValue.contains("MenuBarExtra") ?? false) }) {
            window.makeKeyAndOrderFront(nil)
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