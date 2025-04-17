import SwiftUI

struct ContentView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var codeManager: CodeManager
    @AppStorage("selectedTab") var selectedTab: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            TabView(selection: $selectedTab) {
                HistoryView()
                    .tabItem {
                        Label("历史记录", systemImage: "clock")
                    }
                    .tag(0)
                
                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gear")
                    }
                    .tag(1)
                
                AboutView()
                    .tabItem {
                        Label("关于", systemImage: "info.circle")
                    }
                    .tag(2)
            }
        }
        .onAppear {
            notificationManager.startMonitoring()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NotificationManager())
            .environmentObject(CodeManager())
    }
} 