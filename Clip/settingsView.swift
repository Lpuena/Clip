import SwiftUI
import ServiceManagement
import HotKey
import UserNotifications

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("clipboardHistoryCount") private var clipboardHistoryCount = 20
    @AppStorage("showSourceInHistory") private var showSourceInHistory = true
    @State private var showingClearConfirmation = false
    @EnvironmentObject var clipboardManager: ClipboardManager
    @ObservedObject var hotKeyManager: HotKeyManager
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知版本"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 25) {
                    generalSection
                    historySection
                    hotKeySection
                    dangerZoneSection
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
            
            footer
        }
        .frame(width: 350, height: 450)
        .background(Color(.windowBackgroundColor))
        .alert(isPresented: $showingClearConfirmation) {
            Alert(
                title: Text("确认清空"),
                message: Text("您确定要清空所有剪贴板历史吗？此操作不可撤销。"),
                primaryButton: .destructive(Text("清空")) {
                    clearClipboardHistory()
                },
                secondaryButton: .cancel()
            )
        }
        .overlay(
            Group {
                if hotKeyManager.isRecording {
                    HotKeyRecorder(hotKeyManager: hotKeyManager)
                }
            }
        )
    }
    
    private var header: some View {
        Text("Clip 设置")
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.windowBackgroundColor).opacity(0.8))
    }
    
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("通用")
            HStack {
                Text("开机启动")
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
            }
            .onChange(of: launchAtLogin) { newValue in
                setLaunchAtLogin(newValue)
            }
        }
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("历史记录")
            VStack(alignment: .leading, spacing: 5) {
                Text("保留数量: \(clipboardHistoryCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { Double(clipboardHistoryCount) },
                    set: { clipboardHistoryCount = Int($0) }
                ), in: 5...50, step: 1)
            }
            HStack {
                Text("显示来源应用")
                Spacer()
                Toggle("", isOn: $showSourceInHistory)
                    .labelsHidden()
            }
        }
    }
    
    private var hotKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("快捷键")
            HStack {
                Text(hotKeyManager.hotKeyString)
                    .padding(6)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                Spacer()
                Button("修改") {
                    hotKeyManager.isRecording = true
                }
                .buttonStyle(BorderedButtonStyle())
            }
        }
    }
    
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("危险区域")
            Button(action: {
                showingClearConfirmation = true
            }) {
                Text("清空剪贴板历史")
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var footer: some View {
        Text("版本: \(appVersion)")
            .font(.footnote)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.windowBackgroundColor).opacity(0.8))
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
    
    private func setLaunchAtLogin(_ enable: Bool) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.yourcompany.Clip"
        SMLoginItemSetEnabled(bundleIdentifier as CFString, enable)
    }
    
    private func clearClipboardHistory() {
        clipboardManager.clearHistory()
        print("剪贴板历史已清空")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sendUserNotification()
        }
    }
    
    private func sendUserNotification() {
        let content = UNMutableNotificationContent()
        content.title = "剪贴板已清空"
        content.body = "所有剪贴板历史记录已被清除。"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送通知时出错: \(error)")
            } else {
                print("通知请求已添加")
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(hotKeyManager: HotKeyManager(hotKey: nil, keyDownHandler: nil))
    }
}
