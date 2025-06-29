import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var codeManager: CodeManager
    @State private var selectedCode: VerificationCode?
    @State private var showEmptyState = false
    @State private var selectedSource: String = "全部"
    @State private var selectedTimeRange: TimeRange = .all
    
    enum TimeRange: String, CaseIterable {
        case lastHour = "最近1小时"
        case today = "今天"
        case yesterday = "昨天"
        case lastWeek = "最近7天"
        case all = "全部"
        
        var dateRange: (start: Date, end: Date) {
            let now = Date()
            let calendar = Calendar.current
            
            switch self {
            case .lastHour:
                return (calendar.date(byAdding: .hour, value: -1, to: now)!, now)
            case .today:
                let startOfDay = calendar.startOfDay(for: now)
                return (startOfDay, now)
            case .yesterday:
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
                let startOfYesterday = calendar.startOfDay(for: yesterday)
                let endOfYesterday = calendar.date(byAdding: .day, value: 1, to: startOfYesterday)!
                return (startOfYesterday, endOfYesterday)
            case .lastWeek:
                return (calendar.date(byAdding: .day, value: -7, to: now)!, now)
            case .all:
                return (Date.distantPast, now)
            }
        }
    }
    
    // 获取所有来源
    var allSources: [String] {
        var sources = Set<String>()
        sources.insert("全部")
        codeManager.recentCodes.forEach { sources.insert($0.source) }
        return Array(sources).sorted()
    }
    
    // 过滤后的验证码
    var filteredCodes: [VerificationCode] {
        codeManager.recentCodes.filter { code in
            // 按来源筛选
            let sourceMatch = selectedSource == "全部" || code.source == selectedSource
            
            // 按时间筛选
            let timeRange = selectedTimeRange.dateRange
            let timeMatch = code.timestamp >= timeRange.start && code.timestamp <= timeRange.end
            
            return sourceMatch && timeMatch
        }
    }
    
    var body: some View {
        VStack {
            // 顶部状态区域
            HStack {
                Label("最近捕获的验证码", systemImage: "list.bullet.clipboard")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    codeManager.clearHistory()
                }) {
                    Label("清空历史", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(codeManager.recentCodes.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // 筛选栏
            if !codeManager.recentCodes.isEmpty {
                HStack {
                    // 来源筛选
                    Picker("来源", selection: $selectedSource) {
                        ForEach(allSources, id: \.self) { source in
                            Text(source).tag(source)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                    
                    // 时间筛选
                    Picker("时间", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                    
                    Spacer()
                    
                    // 结果统计
                    Text("共 \(filteredCodes.count) 条记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
            
            if codeManager.recentCodes.isEmpty {
                EmptyStateView()
            } else if filteredCodes.isEmpty {
                // 筛选后无结果
                VStack {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("没有符合筛选条件的验证码")
                        .font(.headline)
                        .padding(.top)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredCodes) { code in
                        CodeListItemView(code: code)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCode = code
                            }
                            .contextMenu {
                                Button(action: {
                                    codeManager.copyToClipboard(code.code)
                                }) {
                                    Label("复制验证码", systemImage: "doc.on.doc")
                                }
                            }
                    }
                }
                .listStyle(InsetListStyle())
            }
        }
        .sheet(item: $selectedCode) { code in
            CodeDetailView(code: code)
                .frame(width: 400, height: 300)
        }
    }
}

struct CodeListItemView: View {
    let code: VerificationCode
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(code.code)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(code.source)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                        )
                }
                
                Text(code.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                CodeManager.shared.copyToClipboard(code.code)
            }) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack {
            Spacer()
            
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无验证码记录")
                .font(.headline)
                .padding(.top)
            
            Text("当接收到验证码通知后，会自动显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
}

struct CodeDetailView: View {
    let code: VerificationCode
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text("验证码详情")
                .font(.headline)
            
            // 验证码
            VStack {
                Text(code.code)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .tracking(4)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.1))
                    )
                
                // 来源和时间
                HStack {
                    Label(code.source, systemImage: "bell")
                    Spacer()
                    Label(code.formattedTime, systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            
            // 操作按钮
            HStack {
                Button(action: {
                    CodeManager.shared.copyToClipboard(code.code)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Label("复制验证码", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("关闭")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
} 