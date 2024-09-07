//
//  ClipApp.swift
//  Clip
//
//  Created by GGG on 2024/9/6.
//

import SwiftUI
import AppKit
import ServiceManagement
import HotKey
import UserNotifications

// MARK: - Main App Structure
@main
struct ClipApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        print("ClipApp 初始化开始")
        NSApplication.shared.setActivationPolicy(.accessory)
        print("应用程序设置为后台运行模式")
        print("ClipApp 初始化完成")
        
        // 请求通知权限
        requestNotificationPermission()
    }
    
    var body: some Scene {
        print("ClipApp body 被调用")
        return Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置") {
                    appDelegate.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .appInfo, addition: {})
            CommandGroup(replacing: .systemServices, addition: {})
            CommandGroup(replacing: .newItem, addition: {})
            CommandGroup(replacing: .undoRedo, addition: {})
            CommandGroup(replacing: .pasteboard, addition: {})
            CommandGroup(replacing: .windowSize, addition: {})
            CommandGroup(replacing: .windowList, addition: {})
            CommandGroup(replacing: .help, addition: {})
        }
        .environmentObject(clipboardManager)
    }
    
    // 添加这个新函数
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("通知权限已获得")
                    self.checkNotificationSettings()
                } else {
                    print("通知权限被拒绝")
                    if let error = error {
                        print("获取通知权限时出错: \(error)")
                    }
                }
            }
        }
    }

    private func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("通知设置:")
            print("授权状态: \(settings.authorizationStatus.rawValue)")
            print("警告设置: \(settings.alertSetting.rawValue)")
            print("声音设置: \(settings.soundSetting.rawValue)")
            print("标记设置: \(settings.badgeSetting.rawValue)")
            print("通知中心设置: \(settings.notificationCenterSetting.rawValue)")
            print("锁定屏幕设置: \(settings.lockScreenSetting.rawValue)")
            print("临界通知设置: \(settings.criticalAlertSetting.rawValue)")
            print("预览设置: \(settings.alertStyle.rawValue)")
            
            if #available(macOS 11.0, *) {
                print("时间敏感设置: \(settings.timeSensitiveSetting.rawValue)")
            }
            
            if #available(macOS 12.0, *) {
                print("调度设置: \(settings.scheduledDeliverySetting.rawValue)")
            }
            
            // 检查是否允许通知
            if settings.authorizationStatus == .authorized {
                print("通知已被允许")
            } else {
                print("通知未被允许，当前状态: \(settings.authorizationStatus)")
            }
        }
    }
}

// MARK: - Environment Values Extension
struct AppDelegateKey: EnvironmentKey {
    static let defaultValue: AppDelegate? = nil
}

extension EnvironmentValues {
    var appDelegate: AppDelegate? {
        get { self[AppDelegateKey.self] }
        set { self[AppDelegateKey.self] = newValue }
    }
}

// MARK: - Clipboard Manager
class ClipboardManager: ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    @AppStorage("clipboardHistoryCount") private var clipboardHistoryCount: Int = 20
    @AppStorage("showSourceInHistory") var showSourceInHistory: Bool = true
    @Published var selectedItemId: UUID?

    init() {
        print("ClipboardManager 初始化")
        // 如果需要，在这里添加任何必要的初始化代码
    }

    func selectItem(_ item: ClipboardItem) {
        selectedItemId = item.id
    }

    func clearHistory() {
        clipboardItems.removeAll()
    }

    func updateClipboardHistory(sourceApp: (name: String, bundleIdentifier: String)? = nil) {
        print("开始更新剪贴板历史")
        if let newItem = ClipboardItem.fromPasteboard(sourceApp: sourceApp) {
            print("创建了的剪贴板项：\(newItem.type)")
            if !clipboardItems.contains(where: { $0.isContentEqual(to: newItem) }) {
                clipboardItems.insert(newItem, at: 0)
                trimClipboardItems()
                print("新项目已添加到历史")
            } else {
                print("目重复，未加")
            }
        } else {
            print("无法创建新的剪贴板项")
        }
    }

    // 新增的公共方法
    func trimHistory() {
        trimClipboardItems()
    }

    private func trimClipboardItems() {
        while clipboardItems.count > clipboardHistoryCount {
            clipboardItems.removeLast()
        }
    }

    func selectAndCopyItem(_ item: ClipboardItem) {
        selectItem(item)
        item.copyToPasteboard()
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var timer: Timer?
    var settingsWindow: NSWindow?
    @Published var clipboardManager: ClipboardManager
    var eventMonitor: Any?
    var previousActiveApp: NSRunningApplication?
    
    @Published var currentAppearance: NSAppearance?
    
    @Published var hotKeyManager: HotKeyManager
    
    @Published var isPopoverShown: Bool = false

    override init() {
        print("AppDelegate 初始化始")
        self.clipboardManager = ClipboardManager()
        self.hotKeyManager = HotKeyManager(hotKey: HotKey(keyCombo: KeyCombo(key: .f4)), keyDownHandler: nil)
        print("ClipboardManager 和 HotKeyManager 初始化完成")
        super.init()
        print("AppDelegate super.init() 完成")
        
        // 在 super.init() 之后设置 keyDownHandler
        self.hotKeyManager.keyDownHandler = { [weak self] in
            self?.togglePopover(nil)
        }
        
        print("AppDelegate 初始化完成")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("applicationDidFinishLaunching 开始")
        setupStatusItem()
        setupPopover()
        updateAppearance()
        startMonitoringClipboard()
        setupEventMonitor()
        UNUserNotificationCenter.current().delegate = self
        print("applicationDidFinishLaunching 完成")
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard History")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }
    
    private func setupPopover() {
        print("setupPopover 开始")
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        
        let contentView = ClipboardHistoryView(openSettings: { [weak self] in
            self?.openSettings()
        })
        .environmentObject(clipboardManager)
        
        // 使用可选绑定安全地访问 currentAppearance
        if let currentAppearance = currentAppearance {
            contentView.environment(\.colorScheme, currentAppearance.name == .darkAqua ? .dark : .light)
        }

        popover?.contentViewController = NSHostingController(rootView: AnyView(contentView))
        print("setupPopover 完成")
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover?.isShown == true {
                // 检查点击是否在弹出窗口外
                if let popoverWindow = strongSelf.popover?.contentViewController?.view.window,
                   !NSPointInRect(NSEvent.mouseLocation, popoverWindow.frame) {
                    strongSelf.closePopover(event)
                }
            }
        }
    }
    
    // Appearance Methods
    @objc func updateAppearance() {
        DispatchQueue.main.async {
            let oldAppearance = self.currentAppearance
            self.currentAppearance = NSApp.effectiveAppearance
            print("外观更新: 旧外观 = \(oldAppearance?.name.rawValue ?? "nil"), 新观 = \(self.currentAppearance?.name.rawValue ?? "nil")")
            self.updatePopoverContent()
            self.updateStatusItemAppearance()
        }
    }
    
    func updatePopoverContent() {
        print("更新 Popover 内容")
        print("当前 currentAppearance: \(currentAppearance?.name.rawValue ?? "nil")")
        
        let contentView = ClipboardHistoryView(openSettings: openSettings)
            .environmentObject(clipboardManager)
            .environment(\.colorScheme, currentAppearance?.name == .darkAqua ? .dark : .light)

        if let hostingController = popover?.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = AnyView(contentView)
        } else {
            popover?.contentViewController = NSHostingController(rootView: AnyView(contentView))
        }

        popover?.appearance = currentAppearance

        if let popoverView = popover?.contentViewController?.view {
            popoverView.wantsLayer = true
            popoverView.layer?.backgroundColor = NSColor.clear.cgColor
        }

        DispatchQueue.main.async {
            self.popover?.contentViewController?.view.setNeedsDisplay(self.popover?.contentViewController?.view.bounds ?? .zero)
        }
    }
    
    func updatePopoverContentWithoutReopening() {
        guard let popover = popover, let hostingController = popover.contentViewController as? NSHostingController<AnyView> else { return }
        
        let contentView = ClipboardHistoryView(openSettings: openSettings)
            .environmentObject(clipboardManager)
            .environment(\.colorScheme, currentAppearance?.name == .darkAqua ? .dark : .light)

        hostingController.rootView = AnyView(contentView)
        hostingController.view.setNeedsDisplay(hostingController.view.bounds)
    }
    
    func updateStatusItemAppearance() {
        print("更新状态栏图标外观")
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard History") {
                image.isTemplate = true
                button.image = image
                print("设置状态栏图标为模板图像")
            }
        }
    }
    
    // Popover Control Methods
    @objc func togglePopover(_ sender: AnyObject?) {
        print("togglePopover 被调用")
        if isPopoverShown {
            print("Popover 当前显示，准备关闭")
            closePopover(sender)
        } else {
            print("Popover 当前未显示，准备打开")
            showPopover(sender)
        }
    }
    
    func showPopover(_ sender: Any?) {
        print("showPopover 被调用")
        previousActiveApp = NSWorkspace.shared.frontmostApplication
        print("显示 Popover，当前外观: \(currentAppearance?.name.rawValue ?? "nil")")
        clipboardManager.selectedItemId = nil
        updateAppearance()
        updatePopoverContentWithoutReopening()
        
        if let popover = popover {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let button = self.statusItem?.button {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                } else {
                    // 如果 statusItem 按钮不可用，在屏幕中央显示 popover
                    if let screen = NSScreen.main {
                        let rect = NSRect(x: screen.frame.width / 2, y: screen.frame.height / 2, width: 1, height: 1)
                        let window = NSWindow(contentRect: rect, styleMask: [], backing: .buffered, defer: true)
                        window.makeKeyAndOrderFront(nil)
                        popover.show(relativeTo: rect, of: window.contentView!, preferredEdge: .minY)
                    }
                }
                self.isPopoverShown = true
                print("Popover 显示完成")
                NSApp.activate(ignoringOtherApps: true)
                self.checkPopoverStatus()
            }
        } else {
            print("Popover 对象为空，无法显示")
        }
    }
    
    @objc func closePopover(_ sender: Any?) {
        print("AppDelegate 正在关闭弹出窗口")
        if let popover = popover, isPopoverShown {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                popover.performClose(sender)
                self.isPopoverShown = false
                print("弹出窗口已关闭")
                self.returnFocusToPreviousApp()
            }
        } else {
            print("弹出窗口已经是关闭状态或不存在")
        }
    }

    func returnFocusToPreviousApp() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let previousApp = self.previousActiveApp {
                previousApp.activate(options: .activateIgnoringOtherApps)
                print("焦点已返回到之前的应用：\(previousApp.localizedName ?? "未知应用")")
            } else {
                print("没有之前的应用信息，无法返回焦点")
            }
            self.previousActiveApp = nil
        }
    }
    
    // Clipboard Monitoring
    func startMonitoringClipboard() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            let currentCount = NSPasteboard.general.changeCount
            if currentCount != UserDefaults.standard.integer(forKey: "LastPasteboardCount") {
                UserDefaults.standard.set(currentCount, forKey: "LastPasteboardCount")
                DispatchQueue.main.async {
                    let sourceApp = self?.getForegroundAppInfo()
                    self?.clipboardManager.updateClipboardHistory(sourceApp: sourceApp)
                    if self?.popover?.isShown == true {
                        self?.updatePopoverContentWithoutReopening()
                    }
                }
            }
        }
    }
    
    // Utility Methods
    private func getForegroundAppInfo() -> (name: String, bundleIdentifier: String)? {
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication {
            return (frontmostApplication.localizedName ?? "未知应用", frontmostApplication.bundleIdentifier ?? "")
        }
        return nil
    }
    
    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 350, height: 450),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false)
            settingsWindow?.title = "Clip 设置"  // 设置窗口标题
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: 
                SettingsView(hotKeyManager: hotKeyManager)
                    .environmentObject(clipboardManager)
            )
            
            // 设置窗口关闭时的调用
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.delegate = self
        }
        
        // 确保应用程序保持为后台运行模式
        NSApp.setActivationPolicy(.accessory)
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        
        // 激活应用程序，但不显示在 Dock 中
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        if popover?.isShown == true {
            popover?.performClose(nil)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
    
    func forceRefreshPopover() {
        updatePopoverContent()
    }

    func checkPopoverStatus() {
        print("Popover 状态检查:")
        print("isShown: \(popover?.isShown ?? false)")
        print("contentViewController: \(popover?.contentViewController != nil)")
        print("contentSize: \(popover?.contentSize ?? .zero)")
        if let window = popover?.contentViewController?.view.window {
            print("window frame: \(window.frame)")
            print("window isVisible: \(window.isVisible)")
        } else {
            print("window: nil")
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Window Delegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 确保应用程序的激活策略仍然是 .accessory
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Clipboard History View
struct ClipboardHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var clipboardManager: ClipboardManager
    var openSettings: () -> Void
    @Environment(\.appDelegate) private var appDelegate
    @State private var copiedItemId: UUID?

    init(openSettings: @escaping () -> Void) {
        print("ClipboardHistoryView 初始化")
        self.openSettings = openSettings
    }

    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                if clipboardManager.clipboardItems.isEmpty {
                    emptyStateView
                } else {
                    clipboardItemsList
                }
                
                Divider()
                
                bottomBar
            }
        }
        .frame(width: 300, height: 400)
        .onAppear {
            print("ClipboardHistoryView 出现")
        }
    }

    private var backgroundView: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color.black : Color.white)
            .opacity(0.3)
            .edgesIgnoringSafeArea(.all)
    }

    private var emptyStateView: some View {
        VStack {
            Image(systemName: "clipboard")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("剪贴板历史为空")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("复制内容后将显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var clipboardItemsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(clipboardManager.clipboardItems) { item in
                    ClipboardItemView(
                        item: item,
                        isSelected: clipboardManager.selectedItemId == item.id,
                        isCopied: copiedItemId == item.id,
                        action: { copyToClipboard(item) }
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var bottomBar: some View {
        HStack {
            Text("Clipboard")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: openSettings) {
                Image(systemName: "gear")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func copyToClipboard(_ item: ClipboardItem) {
        clipboardManager.selectAndCopyItem(item)
        withAnimation {
            copiedItemId = item.id
        }
        // 立即关闭 popover 并返回焦点
        if let appDelegate = appDelegate {
            appDelegate.closePopover(nil)
        } else {
            // 如果 appDelegate 为 nil，我们可以尝试直接关闭 popover
            NSApp.sendAction(#selector(AppDelegate.closePopover(_:)), to: nil, from: nil)
            DispatchQueue.main.async {
                NSApp.hide(nil)
            }
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let clipboardDidUpdate = Notification.Name("clipboardDidUpdate")
    static let clearClipboardHistory = Notification.Name("clearClipboardHistory")
}
