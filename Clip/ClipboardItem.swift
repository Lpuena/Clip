//
//  ClipboardItem.swift
//  Clip
//
//  Created by GGG on 2024/9/7.
//

import Foundation
import AppKit

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
        print("剪贴板中的类型：\(pasteboard.types)")
        
        // 尝试读取多图
        if let images = ImageProcessing.readMultipleImagesFromPasteboard(pasteboard) {
            print("从剪贴板读取到多张图片，数量：\(images.count)")
            let wrappedImages = images.map { ImageWrapper(image: $0) }
            return ClipboardItem(type: .multipleImages, content: wrappedImages, timestamp: Date(), sourceApp: sourceApp)
        }
        
        // 尝试读取单张图片
        if let image = ImageProcessing.readImageFromPasteboard(pasteboard) {
            print("从剪贴板读取到单张图片，尺寸：\(image.size)")
            return ClipboardItem(type: .image, content: ImageWrapper(image: image), timestamp: Date(), sourceApp: sourceApp)
        }
        
        // 尝试读取文本
        if let string = pasteboard.string(forType: .string) {
            print("创建文本项")
            return ClipboardItem(type: .text, content: string, timestamp: Date(), sourceApp: sourceApp)
        }
        
        print("未能识别剪贴板内容")
        return nil
    }
    
    func isContentEqual(to other: ClipboardItem) -> Bool {
        if self.type != other.type {
            return false
        }
        switch self.type {
        case .text:
            return (self.content as? String) == (other.content as? String)
        case .image:
            if let selfImage = (self.content as? ImageWrapper)?.image,
               let otherImage = (other.content as? ImageWrapper)?.image {
                return ImageProcessing.compareImages(selfImage, otherImage)
            }
            return false
        case .multipleImages:
            if let selfImages = (self.content as? [ImageWrapper])?.map({ $0.image }),
               let otherImages = (other.content as? [ImageWrapper])?.map({ $0.image }),
               selfImages.count == otherImages.count {
                return zip(selfImages, otherImages).allSatisfy(ImageProcessing.compareImages)
            }
            return false
        }
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
            if let imageWrapper = content as? ImageWrapper {
                pasteboard.writeObjects([imageWrapper.image])
            }
        case .multipleImages:
            if let imageWrappers = content as? [ImageWrapper] {
                pasteboard.writeObjects(imageWrappers.map { $0.image })
            }
        }
    }
}

class ImageWrapper: NSObject, NSCopying {
    let image: NSImage
    
    init(image: NSImage) {
        self.image = image
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        // 返回同一个实例，而不是创建新的副本
        return self
    }
}

