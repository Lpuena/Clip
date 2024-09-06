//
//  ClipApp.swift
//  Clip
//
//  Created by GGG on 2024/9/6.
//

import SwiftUI
import AppKit
import ServiceManagement

@main
struct ClipApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .environmentObject(clipboardManager)
    }
}

class ClipboardManager: ObservableObject {
    @Published var clipboardItems: [ClipboardItem] = []
    @AppStorage("clipboardHistoryCount") private var clipboardHistoryCount: Int = 20
    @AppStorage("showSourceInHistory") var showSourceInHistory: Bool = true
    @Published var selectedItemId: UUID?

    func selectItem(_ item: ClipboardItem) {
        selectedItemId = item.id
    }

    func clearHistory() {
        clipboardItems.removeAll()
    }

    func updateClipboardHistory(sourceApp: (name: String, bundleIdentifier: String)? = nil) {
        print("开始更新剪贴板历史")
        if let newItem = ClipboardItem.fromPasteboard(sourceApp: sourceApp) {
            print("创建了新的剪贴板项：\(newItem.type)")
            if !clipboardItems.contains(where: { $0.isContentEqual(to: newItem) }) {
                clipboardItems.insert(newItem, at: 0)
                trimClipboardItems()
                print("新项目已添加到历史")
            } else {
                print("新项目与现有项目重复，未添加")
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
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var timer: Timer?
    var settingsWindow: NSWindow?
    @ObservedObject var clipboardManager: ClipboardManager
    var eventMonitor: Any?
    private var previousActiveApp: NSRunningApplication?
    
    override init() {
        self.clipboardManager = ClipboardManager()
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard History")
            button.action = #selector(togglePopover)
        }
        
        // 创建弹出窗口
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: 
            ClipboardHistoryView(openSettings: openSettings)
                .environmentObject(clipboardManager)
        )

        // 设置 NSPopover 的外观
        popover?.appearance = NSAppearance(named: .vibrantLight)
        if let popoverContentView = popover?.contentViewController?.view {
            popoverContentView.wantsLayer = true
            popoverContentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
        
        // 开监听剪贴板变化
        startMonitoringClipboard()
        
        // 保持应用在后台运行
        NSApp.setActivationPolicy(.accessory)
        
        // 添加全局事件监听器
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover?.isShown == true {
                strongSelf.closePopover(event)
            }
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                closePopover(sender)
            } else {
                showPopover(button)
            }
        }
    }
    
    func showPopover(_ sender: Any?) {
        if let button = statusItem?.button {
            // 在显示弹出窗口之前，保存当前激活的应用
            previousActiveApp = NSWorkspace.shared.frontmostApplication
            clipboardManager.selectedItemId = nil  // 重置选中状态
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func closePopover(_ sender: Any?) {
        print("Closing popover")
        popover?.performClose(sender)
        
        // 在关闭弹出窗口后，将焦点返回到之前的应用
        DispatchQueue.main.async { [weak self] in
            if let previousApp = self?.previousActiveApp {
                previousApp.activate(options: .activateIgnoringOtherApps)
            }
            self?.previousActiveApp = nil
        }
    }
    
    func startMonitoringClipboard() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            let currentCount = NSPasteboard.general.changeCount
            if currentCount != UserDefaults.standard.integer(forKey: "LastPasteboardCount") {
                UserDefaults.standard.set(currentCount, forKey: "LastPasteboardCount")
                DispatchQueue.main.async {
                    let sourceApp = self?.getForegroundAppInfo()
                    self?.clipboardManager.updateClipboardHistory(sourceApp: sourceApp)
                }
            }
        }
    }
    
    private func getForegroundAppInfo() -> (name: String, bundleIdentifier: String)? {
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication {
            return (frontmostApplication.localizedName ?? "未知应用", frontmostApplication.bundleIdentifier ?? "")
        }
        return nil
    }
    
    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 350, height: 350), // 更新高度
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false)
            settingsWindow?.title = "设置"
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: 
                SettingsView()
                    .environmentObject(clipboardManager)
            )
            
            // 设置窗口关闭时的回调
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.delegate = self
        }
        
        // 临时改变应用程序的激活策略
        NSApp.setActivationPolicy(.regular)
        
        settingsWindow?.makeKeyAndOrderFront(nil)
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
    @EnvironmentObject var clipboardManager: ClipboardManager
    @AppStorage("clipboardHistoryCount") private var clipboardHistoryCount: Int = 20
    var openSettings: () -> Void
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(clipboardManager.clipboardItems, id: \.id) { item in
                        ClipboardItemView(item: item, isSelected: clipboardManager.selectedItemId == item.id) {
                            copyToClipboard(item)
                        }
                        .id(item.id)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
                .onAppear {
                    scrollProxy = proxy
                }
            }
            
            Divider()
            
            // 底部固定栏
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
        .id(clipboardManager.clipboardItems.count) // 添加这行来确保视图在项目删除时更新
        .frame(width: 300, height: 400)
        .background(Color(NSColor.windowBackgroundColor)) // 使用系统默认的窗口背景色
        .onAppear {
            NotificationCenter.default.addObserver(forName: .clipboardDidUpdate, object: nil, queue: .main) { _ in
                clipboardManager.updateClipboardHistory()
            }
        }
        .onChange(of: clipboardHistoryCount) { _ in
            clipboardManager.trimHistory() // ���新的公共方法
        }
    }
    
    func closePopover() {
        NSApplication.shared.keyWindow?.close()
    }

    func copyToClipboard(_ item: ClipboardItem) {
        clipboardManager.selectItem(item)
        item.copyToPasteboard()
        
        // 提供视觉反馈并关闭托盘
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("Attempting to close popover from copyToClipboard")
            self.clipboardManager.selectedItemId = nil  // 重置选中状态
            self.closePopover()
        }
    }
}

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let type: ItemType
    let content: Any
    let timestamp: Date
    let sourceApp: (name: String, bundleIdentifier: String)?
    
    enum ItemType {
        case text
        case image
        case multipleImages
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
    
    static func fromPasteboard(sourceApp: (name: String, bundleIdentifier: String)? = nil) -> ClipboardItem? {
        let pasteboard = NSPasteboard.general
        
        print("开始处理剪贴板内容")
        
        // 首先尝试直接从剪贴板读取图片内容
        if let images = NSImage.readFromPasteboard(pasteboard) {
            print("从剪板直接读取到 \(images.count) 张图片")
            if images.count > 1 {
                return ClipboardItem(type: .multipleImages, content: images, timestamp: Date(), sourceApp: sourceApp)
            } else if let image = images.first {
                return ClipboardItem(type: .image, content: image, timestamp: Date(), sourceApp: sourceApp)
            }
        }
        
        // 如果没有直接的图片内容，尝试读取文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let imageUrls = urls.filter { url in
                let fileExtension = url.pathExtension.lowercased()
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff","avif"]
                return imageExtensions.contains(fileExtension)
            }
            
            if !imageUrls.isEmpty {
                let images = imageUrls.compactMap { NSImage(contentsOf: $0) }
                if images.count > 1 {
                    print("创建多图片项，共 \(images.count) 张")
                    return ClipboardItem(type: .multipleImages, content: images, timestamp: Date(), sourceApp: sourceApp)
                } else if let image = images.first {
                    print("创建单图片项")
                    return ClipboardItem(type: .image, content: image, timestamp: Date(), sourceApp: sourceApp)
                }
            }
        }
        
        // 尝试读取文本
        if let string = pasteboard.string(forType: .string) {
            print("创建文本项")
            return ClipboardItem(type: .text, content: string, timestamp: Date(), sourceApp: sourceApp)
        }
        
        print("未能识别剪贴板内容")
        return nil
    }
    
    func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch type {
        case .text:
            if let text = content as? String {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let image = content as? NSImage {
                pasteboard.writeObjects([image])
            }
        case .multipleImages:
            if let images = content as? [NSImage] {
                pasteboard.writeObjects(images)
            }
        }
    }
    
    func isContentEqual(to other: ClipboardItem) -> Bool {
        if self.type != other.type {
            return false
        }
        switch self.type {
        case .text:
            return (self.content as? String) == (other.content as? String)
        case .image:
            if let selfImage = self.content as? NSImage,
               let otherImage = other.content as? NSImage,
               let selfData = selfImage.pngData,
               let otherData = otherImage.pngData {
                return selfData == otherData
            }
            return false
        case .multipleImages:
            if let selfImages = self.content as? [NSImage],
               let otherImages = other.content as? [NSImage],
               selfImages.count == otherImages.count {
                for (selfImage, otherImage) in zip(selfImages, otherImages) {
                    if let selfData = selfImage.pngData,
                       let otherData = otherImage.pngData,
                       selfData != otherData {
                        return false
                    }
                }
                return true
            }
            return false
        }
    }
}

// 修改 NSImage 扩展
extension NSImage {
    static func readFromPasteboard(_ pasteboard: NSPasteboard) -> [NSImage]? {
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            return images
        }
        return nil
    }
    
    // 添加一个方法来创建缩略图
    func thumbnail(size: NSSize) -> NSImage {
        let thumbnailImage = NSImage(size: size)
        thumbnailImage.lockFocus()
        defer { thumbnailImage.unlockFocus() }
        
        NSGraphicsContext.current?.imageInterpolation = .high
        if let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rect = NSRect(origin: .zero, size: size)
            NSGraphicsContext.current?.cgContext.draw(cgImage, in: rect)
        }
        
        return thumbnailImage
    }
    
    var pngData: Data? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}

struct ClipboardItemView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    switch item.type {
                    case .text:
                        if let text = item.content as? String {
                            Text(text)
                                .lineLimit(2)
                        }
                    case .image:
                        if let image = item.content as? NSImage {
                            Image(nsImage: image.thumbnail(size: NSSize(width: 80, height: 80)))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                        }
                    case .multipleImages:
                        if let images = item.content as? [NSImage], let firstImage = images.first {
                            HStack {
                                Image(nsImage: firstImage.thumbnail(size: NSSize(width: 80, height: 80)))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                Text("+\(images.count - 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if clipboardManager.showSourceInHistory, let sourceApp = item.sourceApp {
                    Text("来源: \(sourceApp.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7, blendDuration: 0), value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.1)
        } else if isHovered {
            return Color.gray.opacity(0.15)
        } else {
            return Color.clear
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

extension Notification.Name {
    static let clipboardDidUpdate = Notification.Name("clipboardDidUpdate")
    static let clearClipboardHistory = Notification.Name("clearClipboardHistory")
}
