//
//  CloneRaycastApp.swift
//  CloneRaycast
//
//  Created by GGG on 2024/9/6.
//

import SwiftUI
import AppKit

@main
struct CloneRaycastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var timer: Timer?
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard History")
            button.action = #selector(togglePopover)
        }
        
        // 创建弹出窗口
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ClipboardHistoryView(openSettings: openSettings))
        
        // 开始监听剪贴板变化
        startMonitoringClipboard()
        
        // 保持应用在后台运行
        NSApp.setActivationPolicy(.accessory)
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)
            }
        }
    }
    
    func startMonitoringClipboard() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if NSPasteboard.general.changeCount != UserDefaults.standard.integer(forKey: "LastPasteboardCount") {
                UserDefaults.standard.set(NSPasteboard.general.changeCount, forKey: "LastPasteboardCount")
                NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)
            }
        }
    }
    
    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 300, height: 200),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false)
            settingsWindow?.title = "设置"
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: SettingsView())
            
            // 设置窗口关闭时的回调
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.delegate = self
        }
        
        // 临时改变应用程序的激活策略
        NSApp.setActivationPolicy(.regular)
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    deinit {
        timer?.invalidate()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 当设置窗口关闭时，将应用程序的激活策略改回 .accessory
        NSApp.setActivationPolicy(.accessory)
    }
}

struct ClipboardHistoryView: View {
    @State private var clipboardItems: [String] = []
    @State private var selectedItem: String?
    var openSettings: () -> Void
    
    var body: some View {
        ZStack {
            List(clipboardItems, id: \.self) { item in
                Text(item)
                    .lineLimit(2)
                    .onTapGesture {
                        copyToClipboard(item)
                    }
                    .background(selectedItem == item ? Color.blue.opacity(0.3) : Color.clear)
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: openSettings) {
                        Image(systemName: "gear")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding([.bottom, .trailing], 10)
                }
            }
        }
        .frame(width: 300, height: 400)
        .onAppear {
            NotificationCenter.default.addObserver(forName: .clipboardDidUpdate, object: nil, queue: .main) { _ in
                updateClipboardHistory()
            }
        }
    }
    
    func updateClipboardHistory() {
        if let string = NSPasteboard.general.string(forType: .string) {
            if !clipboardItems.contains(string) {
                clipboardItems.insert(string, at: 0)
                if clipboardItems.count > 10 {  // 限制历史记录数量
                    clipboardItems.removeLast()
                }
            }
        }
    }
    
    func copyToClipboard(_ item: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item, forType: .string)
        selectedItem = item
        
        // 提供视觉反馈
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            selectedItem = nil
        }
        
        // 关闭弹出窗口
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.popover?.performClose(nil)
        }
    }
}

extension Notification.Name {
    static let clipboardDidUpdate = Notification.Name("clipboardDidUpdate")
}

