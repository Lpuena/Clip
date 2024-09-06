import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("clipboardHistoryCount") private var clipboardHistoryCount = 20
    @AppStorage("showSourceInHistory") private var showSourceInHistory = true
    @State private var showingClearConfirmation = false
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    // 获取应用版本号
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知版本"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("剪贴板设置")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 15) {
                Toggle(isOn: $launchAtLogin) {
                    Text("开机启动（无效）")
                        .font(.headline)
                }
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(newValue)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("历史记录数量")
                        .font(.headline)
                    
                    HStack {
                        Slider(value: Binding(
                            get: { Double(clipboardHistoryCount) },
                            set: { clipboardHistoryCount = Int($0) }
                        ), in: 5...50, step: 1)
                        
                        Text("\(clipboardHistoryCount)")
                            .frame(width: 30)
                    }
                }
                
                Toggle(isOn: $showSourceInHistory) {
                    Text("显示来源应用")
                        .font(.headline)
                }
                
                Button("清空剪切板历史") {
                    showingClearConfirmation = true
                }
                .foregroundColor(.red)
            }
            .padding()
            .background(Color(.windowBackgroundColor).opacity(0.5))
            .cornerRadius(10)
            
            Spacer()
            
            Text("版本: \(appVersion)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 350, height: 350) // 稍微增加了高度以容纳新的设置项
        .background(Color(.windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .alert(isPresented: $showingClearConfirmation) {
            Alert(
                title: Text("确认清空"),
                message: Text("您确定要清空所有剪切板历史吗？此操作不可撤销。"),
                primaryButton: .destructive(Text("清空")) {
                    clearClipboardHistory()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func setLaunchAtLogin(_ enable: Bool) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.yourcompany.Clip"
        SMLoginItemSetEnabled(bundleIdentifier as CFString, enable)
    }
    
    private func clearClipboardHistory() {
        clipboardManager.clearHistory()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
