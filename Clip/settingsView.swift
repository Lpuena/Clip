import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin: Bool = false
    @State private var shortcut = "Option + Space"
    
    var body: some View {
        Form {
            Toggle("开机启动", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(newValue)
                }
            
            HStack {
                Text("快捷键:")
                TextField("", text: $shortcut)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(true)
            }
            
            Button("保存设置") {
                // 这里添加保存设置的逻辑
                print("保存设置")
            }
        }
        .padding()
        .frame(minWidth: 300, minHeight: 200)
        .onAppear {
            launchAtLogin = getLaunchAtLoginStatus()
        }
    }
    
    private func setLaunchAtLogin(_ enable: Bool) {
        let bundleIdentifier = "com.yourcompany.CloneRaycast" // 替换为您的应用程序的 Bundle Identifier
        
        if enable {
            SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
        } else {
            SMLoginItemSetEnabled(bundleIdentifier as CFString, false)
        }
    }
    
    private func getLaunchAtLoginStatus() -> Bool {
        let bundleIdentifier = "com.yourcompany.CloneRaycast" // 替换为您的应用程序的 Bundle Identifier
        
        var startedAtLogin = false
        if let jobs = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]]) {
            for job in jobs {
                if let bundleId = job["Label"] as? String, bundleId == bundleIdentifier {
                    startedAtLogin = true
                    break
                }
            }
        }
        return startedAtLogin
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
