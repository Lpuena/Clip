//
//  ContentView.swift
//  Clip
//
//  Created by GGG on 2024/9/6.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var searchText = ""
    @State private var items: [Item] = []
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            // 自定义拖动区域
            Color.clear
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let window = NSApplication.shared.windows.first { $0.isKeyWindow }
                            window?.setFrameOrigin(NSPoint(
                                x: value.location.x - dragOffset.width,
                                y: value.location.y - dragOffset.height
                            ))
                        }
                        .onEnded { value in
                            dragOffset = value.translation
                        }
                )
            
            // 主要内容区域
            VStack {
                TextField("搜索...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                ScrollView {
                    LazyVStack {
                        ForEach(items.filter { searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchText) }) { item in
                            Text(item.name)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            
            Divider()
                .background(Color.gray)
            
            // 底部固定栏
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.gray)
                Spacer()
                Text("Clipboard")
                    .font(.headline)
            }
            .padding(.horizontal)
            .frame(height: 40)
        }
        .frame(width: 480, height: 320)
        .background(Color(NSColor.windowBackgroundColor)) // 使用系统默认的窗口背景色
        .cornerRadius(10)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
