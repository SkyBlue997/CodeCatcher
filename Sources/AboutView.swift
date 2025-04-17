import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding()
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                )
            
            // 应用名称和版本
            VStack(spacing: 4) {
                Text("CodeSnatch")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("版本 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 应用描述
            Text("自动捕获并提取系统通知中的验证码，简化您的登录和验证流程。")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.vertical)
            
            // 功能说明
            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "bell", title: "通知监听", description: "监听系统通知，自动检测验证码")
                FeatureRow(icon: "doc.text.magnifyingglass", title: "智能提取", description: "自动识别并提取各种格式的验证码")
                FeatureRow(icon: "doc.on.clipboard", title: "自动复制", description: "验证码自动复制到剪贴板，随时可用")
                FeatureRow(icon: "clock.arrow.circlepath", title: "历史记录", description: "保存最近的验证码，方便查找和使用")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .padding(.horizontal)
            
            Spacer()
            
            // 版权信息
            VStack(spacing: 4) {
                Text("© 2025 CodeSnatch. 保留所有权利。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Text("作者:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Link("@SkyBlue997", destination: URL(string: "https://github.com/SkyBlue997")!)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
} 