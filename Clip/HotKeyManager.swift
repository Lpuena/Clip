//
//  HotKeyManager.swift
//  Clip
//
//  Created by GGG on 2024/9/7.
//

import Foundation
import SwiftUI
import HotKey

class HotKeyManager: ObservableObject {
    @Published var hotKey: HotKey?
    @Published var isRecording = false
    @Published var hotKeyString: String = "未设置"
    var keyDownHandler: (() -> Void)?
    
    init(hotKey: HotKey?, keyDownHandler: (() -> Void)?) {
        self.hotKey = hotKey
        self.keyDownHandler = keyDownHandler
        updateHotKeyString()
        updateHotKey()
    }
    
    func setNewHotKey(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let key = Key(carbonKeyCode: UInt32(event.keyCode)) else {
            print("无法创建 Key")
            return
        }
        
        hotKey = HotKey(keyCombo: KeyCombo(key: key, modifiers: modifiers))
        isRecording = false
        updateHotKeyString()
        updateHotKey()
    }
    
    func setNewHotKey(with keyCombo: KeyCombo) {
        hotKey = HotKey(keyCombo: keyCombo)
        isRecording = false
        updateHotKeyString()
        updateHotKey()
    }
    
    func resetHotKey() {
        hotKey = nil
        hotKeyString = "未设置"
        updateHotKey()
    }
    
    var isHotKeySet: Bool {
        return hotKey != nil
    }
    
    func updateHotKeyString() {
        if let hotKey = hotKey, let key = hotKey.keyCombo.key {
            var modifierString = ""
            if hotKey.keyCombo.modifiers.contains(.command) { modifierString += "⌘" }
            if hotKey.keyCombo.modifiers.contains(.option) { modifierString += "⌥" }
            if hotKey.keyCombo.modifiers.contains(.shift) { modifierString += "⇧" }
            if hotKey.keyCombo.modifiers.contains(.control) { modifierString += "⌃" }
            
            hotKeyString = "\(modifierString)\(key.description)"
        } else {
            hotKeyString = "未设置"
        }
    }
    
    private var lastKeyPressTime: Date?
    private let minimumInterval: TimeInterval = 0.3 // 300毫秒

    func updateHotKey() {
        // 移除旧的热键
        hotKey?.keyDownHandler = nil
        
        // 设置新的热键
        hotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.keyDownHandler?()
            }
        }
    }
}

struct HotKeyRecorder: View {
    @ObservedObject var hotKeyManager: HotKeyManager
    
    var body: some View {
        VStack {
            Text("请按下新的快捷键")
                .font(.headline)
            Text("按 ESC 取消")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(10)
        .shadow(radius: 10)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // ESC key
                    hotKeyManager.isRecording = false
                } else {
                    hotKeyManager.setNewHotKey(event)
                }
                return nil
            }
        }
    }
}

struct CustomViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
    }
}
