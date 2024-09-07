//
//  ImageProcessing.swift
//  Clip
//
//  Created by GGG on 2024/9/7.
//

import AppKit

struct ImageProcessing {
    static func readMultipleImagesFromPasteboard(_ pasteboard: NSPasteboard) -> [NSImage]? {
        let classes = [NSURL.self, NSImage.self]
        let options = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes: NSImage.imageTypes]
        
        guard let objects = pasteboard.readObjects(forClasses: classes, options: options) else {
            return nil
        }
        
        let images = objects.compactMap { object -> NSImage? in
            if let image = object as? NSImage {
                return image
            } else if let url = object as? URL, let image = NSImage(contentsOf: url) {
                return image
            }
            return nil
        }
        
        return images.count > 1 ? images : nil
    }
    
    static func readImageFromPasteboard(_ pasteboard: NSPasteboard) -> NSImage? {
        let classes = [NSURL.self, NSImage.self]
        let options = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes: NSImage.imageTypes]
        
        if let objects = pasteboard.readObjects(forClasses: classes, options: options),
           let firstObject = objects.first {
            if let image = firstObject as? NSImage {
                return image
            } else if let url = firstObject as? URL, let image = NSImage(contentsOf: url) {
                return image
            }
        }
        
        // 尝试从文件路径读取
        if let filePaths = pasteboard.propertyList(forType: .fileURL) as? [String],
           let firstPath = filePaths.first,
           let image = NSImage(contentsOfFile: firstPath) {
            return image
        }
        
        // 尝试从 TIFF 数据读取
        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            return image
        }
        
        return nil
    }
    
    static func compareImages(_ image1: NSImage, _ image2: NSImage) -> Bool {
        // 这里实现更复杂的图片比较逻辑
        guard let data1 = image1.tiffRepresentation,
              let data2 = image2.tiffRepresentation else {
            return false
        }
        return data1 == data2
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}

extension NSPasteboard.PasteboardType {
    static let jpeg = NSPasteboard.PasteboardType("public.jpeg")
    static let gif = NSPasteboard.PasteboardType("com.compuserve.gif")
}
