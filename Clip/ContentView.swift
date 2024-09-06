//
//  ContentView.swift
//  CloneRaycast
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
            
            VStack {
                TextField("搜索...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                List(items.filter { searchText.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchText) }) { item in
                    Text(item.name)
                }
            }
            .frame(width: 480, height: 280)
        }
        .background(VisualEffectView().ignoresSafeArea())
        .cornerRadius(10)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
