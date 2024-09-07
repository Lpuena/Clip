//
//  ClipboardItemView.swift
//  Clip
//
//  Created by GGG on 2024/9/7.
//

import SwiftUI

struct ClipboardItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: ClipboardItem
    let isSelected: Bool
    let isCopied: Bool
    let action: () -> Void
    @State private var isHovered = false
    @EnvironmentObject var clipboardManager: ClipboardManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                itemIcon
                itemContent
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity) // 确保 HStack 填满整个宽度
            .contentShape(Rectangle()) // 使整个区域可点击
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var itemIcon: some View {
        Group {
            switch item.type {
            case .text:
                Image(systemName: "doc.text")
            case .image:
                Image(systemName: "photo")
            case .multipleImages:
                Image(systemName: "photo.on.rectangle")
            }
        }
        .foregroundColor(.secondary)
        .frame(width: 24, height: 24)
    }
    
    private var itemContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch item.type {
            case .text:
                if let text = item.content as? String {
                    Text(text)
                        .lineLimit(2)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                }
            case .image:
                if let imageWrapper = item.content as? ImageWrapper,
                   let image = imageWrapper.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 60)
                }
            case .multipleImages:
                if let imageWrappers = item.content as? [ImageWrapper],
                   let firstImageWrapper = imageWrappers.first,
                   let firstImage = firstImageWrapper.image {
                    HStack {
                        Image(nsImage: firstImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 60)
                        if imageWrappers.count > 1 {
                            Text("+\(imageWrappers.count - 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if clipboardManager.showSourceInHistory, let sourceApp = item.sourceApp {
                Text("来源: \(sourceApp.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.1)
        } else if isHovered {
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color(NSColor.selectedControlColor).opacity(0.5)
        } else {
            return Color.clear
        }
    }
}
