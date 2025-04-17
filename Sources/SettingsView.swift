import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var codeManager: CodeManager
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var appearanceManager = AppearanceManager.shared
    @StateObject private var aiDetector = AICodeDetector.shared
    
    @State private var hasAccessibilityPermission = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            Text("应用设置")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    Group {
                        // 开机自启动设置
                        Toggle(isOn: $launchAtLogin) {
                            Label("开机自启动", systemImage: "power")
                        }
                        .toggleStyle(SwitchToggleStyle())
                        .onChange(of: launchAtLogin) { newValue in
                            if newValue {
                                LaunchAtLogin.enable()
                            } else {
                                LaunchAtLogin.disable()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        Divider().padding(.vertical, 2)
                        
                        // 外观模式设置
                        VStack(alignment: .leading, spacing: 2) {
                            Label("外观模式", systemImage: "circle.lefthalf.filled")
                                .font(.body)
                                .padding(.bottom, 2)
                            
                            Picker("", selection: $appearanceManager.currentAppearance) {
                                ForEach(AppAppearance.allCases) { appearance in
                                    Text(appearance.displayName).tag(appearance)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            Text("设置应用的外观模式")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        Divider().padding(.vertical, 2)
                        
                        // 语言设置
                        VStack(alignment: .leading, spacing: 2) {
                            Label("语言", systemImage: "globe")
                                .font(.body)
                                .padding(.bottom, 2)
                            
                            Picker("", selection: $localizationManager.currentLanguage) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            Text("重启应用后生效")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                    
                    Group {
                        Divider().padding(.vertical, 2)
                        
                        // AI验证码检测设置
                        VStack(alignment: .leading, spacing: 2) {
                            Toggle(isOn: $aiDetector.isEnabled) {
                                Label("基于AI的验证码检测", systemImage: "brain")
                            }
                            .toggleStyle(SwitchToggleStyle())
                            
                            Text("使用本地AI技术提高验证码识别准确率")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        Divider().padding(.vertical, 2)
                        
                        // 监听通知设置
                        Toggle(isOn: Binding(
                            get: { notificationManager.isMonitoring },
                            set: { newValue in
                                if newValue {
                                    notificationManager.startMonitoring()
                                } else {
                                    notificationManager.stopMonitoring()
                                }
                            }
                        )) {
                            Label("监听系统通知", systemImage: "bell")
                        }
                        .toggleStyle(SwitchToggleStyle())
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        // 验证辅助功能权限
                        HStack {
                            Label("辅助功能权限", systemImage: "hand.raised")
                            Spacer()
                            if hasAccessibilityPermission {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Button("请求权限") {
                                    notificationManager.requestAccessibilityPermission()
                                    // 延迟检查权限状态，因为用户可能需要时间来授权
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        checkPermission()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        // 完全磁盘访问权限（用于短信监控）
                        HStack {
                            Label("完全磁盘访问权限", systemImage: "externaldrive.fill")
                            Spacer()
                            if notificationManager.checkFullDiskAccessPermission() {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Button("请求权限") {
                                    notificationManager.requestFullDiskAccessPermission()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        // 启用短信监控按钮
                        Button("启用增强短信监控") {
                            notificationManager.setupSMSMonitoring()
                        }
                        .disabled(!notificationManager.checkFullDiskAccessPermission())
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                    
                    Group {
                        Divider().padding(.vertical, 2)
                        
                        // 历史记录保留时间设置
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("历史记录保留时间")
                                    .font(.body)
                                Spacer()
                                Text("\(String(format: "%.0f", codeManager.historyRetentionHours))小时")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: Binding(
                                get: { codeManager.historyRetentionHours },
                                set: { codeManager.updateHistoryRetention($0) }
                            ), in: 1...168, step: 1) // 1小时到7天（168小时）
                            
                            Text("验证码记录将在超过保留时间后自动删除。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        Divider().padding(.vertical, 2)
                        
                        // 监控剪贴板设置
                        Toggle(isOn: Binding(
                            get: { codeManager.isMonitoringClipboard },
                            set: { newValue in
                                if newValue {
                                    codeManager.startMonitoringClipboard()
                                } else {
                                    codeManager.stopMonitoringClipboard()
                                }
                            }
                        )) {
                            Label("监听剪贴板", systemImage: "doc.on.clipboard")
                        }
                        .toggleStyle(SwitchToggleStyle())
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        // 剪贴板检测间隔
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("检测间隔")
                                    .font(.body)
                                Spacer()
                                Text("\(String(format: "%.1f", codeManager.clipboardCheckInterval))秒")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: Binding(
                                get: { codeManager.clipboardCheckInterval },
                                set: { codeManager.updateClipboardCheckInterval($0) }
                            ), in: 0.5...10, step: 0.5)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        Text("复制新代码之前剪贴板更改的最短时间。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 6)
                    }
                    
                    Group {
                        Divider().padding(.vertical, 2)
                        
                        // 自动复制设置
                        Toggle(isOn: Binding(
                            get: { codeManager.autoClipboard },
                            set: { newValue in
                                codeManager.autoClipboard = newValue
                                codeManager.saveSettings()
                            }
                        )) {
                            Label("自动复制到剪贴板", systemImage: "doc.on.clipboard")
                        }
                        .toggleStyle(SwitchToggleStyle())
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        Text("当识别到验证码时，自动复制到剪贴板")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 6)
                        
                        // 权限说明部分
                        VStack(alignment: .leading, spacing: 4) {
                            Text("关于辅助功能权限")
                                .font(.headline)
                            
                            Text("为了读取通知内容，验证码捕手需要获取辅助功能权限。这些权限仅用于读取通知内容以提取验证码，不会用于其他目的。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("如何开启权限：")
                                .font(.subheadline)
                                .padding(.top, 2)
                            
                            Text("1. 前往系统设置 > 隐私与安全性 > 辅助功能\n2. 在列表中勾选\"验证码捕手\"\n3. 重启应用程序")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        
                        // 添加底部填充，确保最后一项不会紧贴底部
                        Color.clear
                            .frame(height: 10)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            checkPermission()
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
    
    private func checkPermission() {
        Task { @MainActor in
            hasAccessibilityPermission = notificationManager.checkAccessibilityPermission()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(NotificationManager())
            .environmentObject(CodeManager())
    }
} 